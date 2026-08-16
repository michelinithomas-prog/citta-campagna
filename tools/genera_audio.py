#!/usr/bin/env python3
"""Genera i suoni e la musica di Città & Campagna.

    python3 tools/genera_audio.py            # scrive game/audio/
    python3 tools/genera_audio.py --referto  # solo le misure, non scrive niente
    python3 tools/genera_audio.py --solo hit # un suono solo, per iterare in fretta

L'idea, che è anche il vincolo: **tutto il gioco suona con gli stessi due
materiali**, l'ancia della fisarmonica e il legno del bancone. Niente bip da
console — non perché i bip siano brutti, ma perché il gioco è ambientato in un
bar di Gaiofana e un bip lì dentro non l'ha mai sentito nessuno.

Sostituire un file generato con una registrazione vera non richiede codice:
`core/autoload/audio.gd` cerca prima il file e sintetizza solo se non lo trova.
Questo strumento riempie quella cartella, non prende il posto di quel meccanismo.

Determinismo: ogni suono nasce da un seme fisso. Rigenerare due volte dà file
identici byte per byte — così un diff dice se hai cambiato qualcosa davvero.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
SEME = 4242


# ═══════════════════════════════════════════════════════════════════════════
#  I mattoni
# ═══════════════════════════════════════════════════════════════════════════

def n_campioni(dur: float) -> int:
    return max(1, int(SR * dur))


def nota(midi: float) -> float:
    """Frequenza di una nota MIDI. 69 = La4 = 440 Hz."""
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


class Traccia:
    """Un buffer su cui si mescola a tempo assoluto.

    Concatenare pezzi sembra più semplice e si paga subito: basta un pezzo
    lungo un campione in meno e il tempo va alla deriva. Qui ogni suono va
    dove deve andare, e se due si sovrappongono si sommano — che è quello
    che fanno anche nella realtà.
    """

    def __init__(self, durata: float, canali: int = 1):
        self.buf = np.zeros((n_campioni(durata), canali))
        self.canali = canali

    def mescola(self, x: np.ndarray, quando: float = 0.0, guadagno: float = 1.0,
                pan: float = 0.0) -> "Traccia":
        i = n_campioni(quando) if quando > 0 else 0
        fine = min(i + len(x), len(self.buf))
        if fine <= i:
            return self
        pezzo = x[: fine - i] * guadagno
        if self.canali == 1:
            self.buf[i:fine, 0] += pezzo
        else:
            # pan a potenza costante: a centro nessuno dei due canali cala
            ang = (pan + 1.0) * 0.25 * np.pi
            self.buf[i:fine, 0] += pezzo * np.cos(ang)
            self.buf[i:fine, 1] += pezzo * np.sin(ang)
        return self

    def uscita(self) -> np.ndarray:
        return self.buf[:, 0] if self.canali == 1 else self.buf


# ── inviluppi ──────────────────────────────────────────────────────────────

def env_adsr(n: int, a=0.005, d=0.05, s=0.6, r=0.2) -> np.ndarray:
    a_n, d_n, r_n = n_campioni(a), n_campioni(d), n_campioni(r)
    if a_n + d_n + r_n > n:                       # nota più corta del suo stesso
        k = n / (a_n + d_n + r_n)                 # inviluppo: si comprime tutto
        a_n, d_n, r_n = int(a_n * k), int(d_n * k), int(r_n * k)
    s_n = max(0, n - a_n - d_n - r_n)
    parti = [
        np.linspace(0.0, 1.0, a_n, endpoint=False),
        np.linspace(1.0, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0.0, max(1, r_n)),
    ]
    return np.concatenate(parti)[:n]


def env_perc(n: int, attacco=0.002, decadimento=0.10) -> np.ndarray:
    """Sale in un istante, scende in esponenziale. È il colpo."""
    t = np.arange(n) / SR
    env = np.exp(-t / max(decadimento, 1e-4))
    a_n = max(1, n_campioni(attacco))
    env[:a_n] *= np.linspace(0.0, 1.0, a_n)
    return env


# ── oscillatori ────────────────────────────────────────────────────────────

def _fase(freq, n: int) -> np.ndarray:
    """Fase integrata: accetta una frequenza costante o un glissando."""
    t = np.arange(n) / SR
    if np.isscalar(freq):
        return 2 * np.pi * freq * t
    return 2 * np.pi * np.cumsum(np.asarray(freq, dtype=float)) / SR


def sega(freq, n: int, detune_cent: float = 0.0) -> np.ndarray:
    """Dente di sega sommato armonica per armonica.

    Costa più di una formula chiusa e in cambio non produce aliasing: sopra
    Nyquist semplicemente non ci va. Su suoni corti la differenza non si
    sente, su un accordo tenuto sì.
    """
    f = np.asarray(freq, dtype=float) * (2.0 ** (detune_cent / 1200.0))
    f_max = float(np.max(f))
    out = np.zeros(n)
    k = 1
    while f_max * k < SR * 0.45:
        out += np.sin(_fase(f * k, n)) / k
        k += 1
        if k > 200:
            break
    return out * (2.0 / np.pi)


def seno(freq, n: int) -> np.ndarray:
    return np.sin(_fase(freq, n))


def triangolo(freq, n: int) -> np.ndarray:
    out = np.zeros(n)
    f = np.asarray(freq, dtype=float)
    f_max = float(np.max(f))
    k = 1
    while f_max * k < SR * 0.45:
        if k % 2 == 1:
            segno = 1.0 if (k - 1) % 4 == 0 else -1.0
            out += segno * np.sin(_fase(f * k, n)) / (k * k)
        k += 1
        if k > 100:
            break
    return out * (8.0 / (np.pi ** 2))


def rumore(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


# ── filtri ─────────────────────────────────────────────────────────────────

def passa_basso(x: np.ndarray, taglio: float) -> np.ndarray:
    """Un polo, applicato con lfilter: veloce e abbastanza dolce."""
    from scipy.signal import lfilter
    a = float(np.exp(-2 * np.pi * taglio / SR))
    return lfilter([1 - a], [1, -a], x)


def passa_alto(x: np.ndarray, taglio: float) -> np.ndarray:
    return x - passa_basso(x, taglio)


def risonante(x: np.ndarray, freq: float, q: float = 6.0) -> np.ndarray:
    """Campana risonante: serve a dare una nota a del rumore.

    È così che si fa un legno che risuona senza avere un campione di legno.
    """
    from scipy.signal import lfilter
    w = 2 * np.pi * freq / SR
    r = np.exp(-w / (2 * q))
    b = [1 - r]
    a = [1, -2 * r * np.cos(w), r * r]
    return lfilter(b, a, x)


# ── rifinitura ─────────────────────────────────────────────────────────────

def smussa(x: np.ndarray, ms: float = 3.0) -> np.ndarray:
    """Sfuma i due bordi. Un taglio netto è un click, e si sente su tutto."""
    n = n_campioni(ms / 1000.0)
    if len(x) < 2 * n:
        return x
    y = x.copy()
    y[:n] *= np.linspace(0.0, 1.0, n)
    y[-n:] *= np.linspace(1.0, 0.0, n)
    return y


def normalizza(x: np.ndarray, picco: float = 0.9) -> np.ndarray:
    m = float(np.max(np.abs(x)))
    return x if m < 1e-9 else x / m * picco


def riverbero(x: np.ndarray, quanto: float = 0.18, stanza: float = 0.06,
              rng: np.random.Generator | None = None) -> np.ndarray:
    """Una stanza piccola — il bar, non la cattedrale.

    Non è un riverbero vero: sono poche riflessioni scure. Basta a togliere ai
    suoni quell'aria di 'registrato nel vuoto' che tradisce la sintesi.
    """
    if quanto <= 0:
        return x
    rng = rng or np.random.default_rng(SEME)
    coda = n_campioni(stanza * 4)
    y = np.pad(x, (0, coda))
    for i in range(6):
        ritardo = n_campioni(stanza * (0.35 + 0.55 * i) * (1.0 + 0.13 * i))
        att = quanto * (0.62 ** i)
        if ritardo < len(y):
            eco = passa_basso(y[: len(y) - ritardo], 2400) * att
            y[ritardo:ritardo + len(eco)] += eco
    return y


# ═══════════════════════════════════════════════════════════════════════════
#  I due materiali del gioco
# ═══════════════════════════════════════════════════════════════════════════

def ancia(midi: float, dur: float, musette: float = 13.0, corpo: float = 2200.0,
          attacco: float = 0.040, rilascio: float = 0.09,
          vibrato: float = 4.8, prof_vib: float = 0.010) -> np.ndarray:
    """L'ancia della fisarmonica.

    Il segreto non è la forma d'onda: sono **due ance quasi accordate** che
    battono fra loro. Quel battimento — il musette — è ciò che l'orecchio
    riconosce come fisarmonica. Toglilo e resta un organo.
    """
    n = n_campioni(dur)
    t = np.arange(n) / SR
    f = nota(midi) * (1.0 + prof_vib * np.sin(2 * np.pi * vibrato * t) *
                      np.clip(t / 0.25, 0, 1))     # il vibrato entra dopo l'attacco
    voce = (sega(f, n) +
            sega(f, n, +musette) * 0.82 +
            sega(f, n, -musette * 0.68) * 0.64)
    voce = passa_basso(voce, corpo)
    voce += seno(f * 0.5, n) * 0.12               # un filo di sub, dà peso
    env = env_adsr(n, a=attacco, d=0.10, s=0.80, r=rilascio)
    return smussa(voce * env / 2.6)


def legno(freq: float, dur: float, rng: np.random.Generator,
          durezza: float = 0.55, decadimento: float = 0.055) -> np.ndarray:
    """Il bancone: un colpo secco su legno.

    Rumore filtrato attraverso due risonanze — è il modo più corto per avere
    un materiale invece di un bip.
    """
    n = n_campioni(dur)
    imp = rumore(n, rng) * env_perc(n, attacco=0.0008, decadimento=decadimento * 0.35)
    corpo = risonante(imp, freq, q=7.0) + risonante(imp, freq * 2.71, q=4.0) * 0.45
    corpo += passa_alto(imp, 3500) * durezza * 0.30
    return smussa(corpo * env_perc(n, attacco=0.001, decadimento=decadimento), 2.0)


def carta(dur: float, rng: np.random.Generator, brillantezza: float = 5200.0) -> np.ndarray:
    """Una carta che si stacca dal mazzo: rumore breve e chiaro, niente tono."""
    n = n_campioni(dur)
    x = rumore(n, rng)
    x = passa_alto(passa_basso(x, brillantezza), 1400)
    return smussa(x * env_perc(n, attacco=0.0012, decadimento=dur * 0.30), 1.5)


def metallo(midi: float, dur: float, disarmonia: float = 1.0) -> np.ndarray:
    """La moneta sul bancone. Parziali non armonici: è ciò che fa 'metallo'."""
    n = n_campioni(dur)
    f = nota(midi)
    parziali = [(1.0, 1.0), (2.76, 0.55), (5.40, 0.32), (8.93, 0.18)]
    out = np.zeros(n)
    for i, (rap, amp) in enumerate(parziali):
        r = 1.0 + (rap - 1.0) * disarmonia
        out += seno(f * r, n) * amp * env_perc(n, attacco=0.0006,
                                               decadimento=dur * (0.42 - 0.07 * i))
    return smussa(out * 0.5, 1.5)


# ═══════════════════════════════════════════════════════════════════════════
#  I suoni del gioco
#
#  Ogni voce è una funzione che restituisce un array mono già normalizzato.
#  Il nome della chiave è il nome del file: è quello che core/autoload/audio.gd
#  cerca in game/audio/ prima di sintetizzare per conto suo.
# ═══════════════════════════════════════════════════════════════════════════

def s_hit(rng):
    """Un colpo che va a segno. Legno + un morso in alto, corto."""
    n = n_campioni(0.16)
    x = Traccia(0.16)
    x.mescola(legno(196.0, 0.16, rng, durezza=0.8, decadimento=0.045), 0.0, 1.0)
    x.mescola(seno(np.linspace(320, 150, n), n) * env_perc(n, decadimento=0.035), 0.0, 0.55)
    return normalizza(riverbero(x.uscita(), 0.12, 0.045, rng), 0.86)


def s_hurt(rng):
    """Il colpo che prendi tu: stesso legno, più cupo e più lento."""
    n = n_campioni(0.26)
    x = Traccia(0.26)
    x.mescola(legno(104.0, 0.26, rng, durezza=0.35, decadimento=0.10), 0.0, 1.0)
    x.mescola(seno(np.linspace(190, 78, n), n) * env_perc(n, decadimento=0.075), 0.0, 0.7)
    return normalizza(riverbero(x.uscita(), 0.16, 0.05, rng), 0.86)


def s_explosion(rng):
    """Qualcosa di grosso: il tavolo che salta."""
    n = n_campioni(0.55)
    x = Traccia(0.55)
    x.mescola(passa_basso(rumore(n, rng), 900) * env_perc(n, attacco=0.002, decadimento=0.16), 0.0, 1.0)
    x.mescola(seno(np.linspace(150, 42, n), n) * env_perc(n, decadimento=0.13), 0.0, 0.9)
    x.mescola(legno(88.0, 0.30, rng, durezza=0.9, decadimento=0.09), 0.0, 0.6)
    return normalizza(riverbero(x.uscita(), 0.26, 0.075, rng), 0.88)


def s_click(rng):
    """Una carta appoggiata sul tavolo. Il suono più frequente del gioco:
    deve essere corto, chiaro e non stancare mai."""
    x = Traccia(0.075)
    x.mescola(carta(0.055, rng, brillantezza=6200.0), 0.0, 0.75)
    x.mescola(legno(680.0, 0.06, rng, durezza=0.30, decadimento=0.016), 0.004, 0.45)
    return normalizza(x.uscita(), 0.62)


def s_confirm(rng):
    """Due note d'ancia che salgono: sì."""
    x = Traccia(0.42)
    x.mescola(ancia(69, 0.16, attacco=0.012, rilascio=0.05), 0.00, 0.75)
    x.mescola(ancia(76, 0.26, attacco=0.012, rilascio=0.10), 0.10, 0.85)
    return normalizza(riverbero(x.uscita(), 0.18, 0.055, rng), 0.80)


def s_cancel(rng):
    """Due note che scendono: no. Stesso gesto rovesciato."""
    x = Traccia(0.36)
    x.mescola(ancia(69, 0.14, attacco=0.010, rilascio=0.05), 0.00, 0.70)
    x.mescola(ancia(64, 0.22, attacco=0.010, rilascio=0.09), 0.09, 0.70)
    return normalizza(riverbero(x.uscita(), 0.15, 0.05, rng), 0.74)


def s_error(rng):
    """L'ancia che strozza. Un semitono sotto, tenuto: stona apposta."""
    x = Traccia(0.30)
    x.mescola(ancia(56, 0.26, musette=26.0, corpo=1300.0, attacco=0.008, rilascio=0.09), 0.0, 0.9)
    x.mescola(ancia(57, 0.24, musette=26.0, corpo=1300.0, attacco=0.008, rilascio=0.09), 0.0, 0.7)
    return normalizza(x.uscita(), 0.74)


def s_coin(rng):
    """Oro. Due monete sul bancone, la seconda subito dopo."""
    x = Traccia(0.34)
    x.mescola(metallo(93, 0.22), 0.000, 0.9)
    x.mescola(metallo(98, 0.26), 0.055, 0.7)
    return normalizza(riverbero(x.uscita(), 0.20, 0.045, rng), 0.80)


def s_buy(rng):
    """Comprato: la moneta che scivola e la carta che arriva."""
    x = Traccia(0.46)
    x.mescola(metallo(88, 0.20), 0.000, 0.75)
    x.mescola(metallo(95, 0.22), 0.045, 0.55)
    x.mescola(carta(0.09, rng, brillantezza=5000.0), 0.13, 0.60)
    x.mescola(ancia(72, 0.24, attacco=0.014, rilascio=0.10), 0.15, 0.55)
    return normalizza(riverbero(x.uscita(), 0.20, 0.055, rng), 0.84)


def s_level_up(rng):
    """Un Gaiofanamon che evolve. Un arpeggio che sale e non torna:
    la crescita resta per il resto della partita, e il suono lo dice."""
    x = Traccia(0.85)
    for i, m in enumerate([60, 64, 67, 72]):
        x.mescola(ancia(m, 0.34 + 0.06 * i, attacco=0.016, rilascio=0.14),
                  0.085 * i, 0.62 + 0.06 * i)
    return normalizza(riverbero(x.uscita(), 0.26, 0.070, rng), 0.86)


def s_win(rng):
    """Vinta. La cadenza più ovvia che esista, suonata da un'ancia sola:
    non è una fanfara, è l'oste che sorride."""
    x = Traccia(1.5)
    x.mescola(ancia(67, 0.26, attacco=0.020, rilascio=0.10), 0.00, 0.70)
    x.mescola(ancia(72, 0.26, attacco=0.020, rilascio=0.10), 0.16, 0.75)
    for m, g in [(64, 0.55), (67, 0.55), (72, 0.75), (76, 0.60)]:
        x.mescola(ancia(m, 0.95, attacco=0.030, rilascio=0.40), 0.34, g)
    return normalizza(riverbero(x.uscita(), 0.30, 0.085, rng), 0.86)


def s_lose(rng):
    """Persa. Stessa ancia, terza minore, e l'ultima nota che cala."""
    x = Traccia(1.7)
    x.mescola(ancia(65, 0.32, attacco=0.030, rilascio=0.14), 0.00, 0.66)
    x.mescola(ancia(63, 0.32, attacco=0.030, rilascio=0.14), 0.22, 0.62)
    for m, g in [(48, 0.70), (55, 0.48), (60, 0.52), (63, 0.44)]:
        x.mescola(ancia(m, 1.10, attacco=0.055, rilascio=0.55, vibrato=3.4), 0.46, g)
    return normalizza(riverbero(x.uscita(), 0.32, 0.095, rng), 0.82)


def s_hover(rng):
    """Il mouse che passa su un bottone.

    Il più insidioso dei sedici: `Ui.button` lo aggancia a ogni controllo del
    gioco, quindi si sente centinaia di volte in una partita e non deve
    lasciare traccia. È il bordo di una carta sfiorato, niente di più: corto,
    scuro, e a un quinto del volume degli altri.
    """
    n = n_campioni(0.032)
    x = passa_alto(passa_basso(rumore(n, rng), 3400), 900)
    return normalizza(smussa(x * env_perc(n, attacco=0.001, decadimento=0.010), 1.0), 0.20)


def s_tick(rng):
    """Il battito della macchina da scrivere nei dialoghi. Una lettera.

    Va sentito quaranta volte in una battuta: deve essere un puntino di legno,
    non una nota — una nota, ripetuta, diventa una melodia involontaria.
    """
    n = n_campioni(0.026)
    x = risonante(rumore(n, rng) * env_perc(n, attacco=0.0004, decadimento=0.004), 1150.0, q=3.5)
    return normalizza(smussa(x, 1.0), 0.30)


def s_crit(rng):
    """Un colpo che conta il doppio: lo stesso legno di `hit`, ma spaccato."""
    n = n_campioni(0.24)
    x = Traccia(0.24)
    x.mescola(legno(147.0, 0.24, rng, durezza=1.0, decadimento=0.075), 0.0, 1.0)
    x.mescola(seno(np.linspace(420, 120, n), n) * env_perc(n, decadimento=0.05), 0.0, 0.6)
    x.mescola(passa_alto(rumore(n, rng), 4200) * env_perc(n, decadimento=0.018), 0.0, 0.35)
    return normalizza(riverbero(x.uscita(), 0.16, 0.05, rng), 0.88)


def s_whoosh(rng):
    """Una carta che scivola via. Rumore che si scurisce mentre passa."""
    n = n_campioni(0.20)
    x = rumore(n, rng)
    # il taglio scende nel tempo: è quello che dà la direzione al gesto
    pezzi = np.array_split(np.arange(n), 8)
    y = np.zeros(n)
    for i, idx in enumerate(pezzi):
        y[idx] = passa_basso(x[idx], 6000 - 620 * i)
    env = np.hanning(n) ** 1.6
    return normalizza(smussa(y * env, 2.0), 0.55)


SUONI = {
    "hit": s_hit,
    "crit": s_crit,
    "hurt": s_hurt,
    "explosion": s_explosion,
    "click": s_click,
    "hover": s_hover,
    "tick": s_tick,
    "whoosh": s_whoosh,
    "confirm": s_confirm,
    "cancel": s_cancel,
    "error": s_error,
    "coin": s_coin,
    "buy": s_buy,
    "level_up": s_level_up,
    "win": s_win,
    "lose": s_lose,
}


# ═══════════════════════════════════════════════════════════════════════════
#  La musica
#
#  Liscio romagnolo: valzer in 3/4, basso sull'uno, accordo sul due e sul tre.
#  È la musica che in un bar di Gaiofana ci sarebbe davvero — e per una volta
#  il riferimento colto e quello giusto coincidono.
# ═══════════════════════════════════════════════════════════════════════════

# Do maggiore. Ogni voce: (basso, [note dell'accordo])
DO   = (36, [48, 52, 55])
SOL7 = (43, [47, 50, 53])
FA   = (41, [45, 48, 53])
LAm  = (33, [45, 48, 52])
REm  = (38, [45, 50, 53])


def _valzer(giro, bpm, battute_per_accordo=2, melodia=None, guadagno_melodia=0.55,
            rng=None):
    """Costruisce un valzer e lo restituisce stereo, già in loop chiuso.

    Come si chiude il loop, e perché non nel modo ovvio.

    Il modo ovvio è rendere il pezzo una volta e ripiegare la coda sull'inizio.
    Non funziona: *sposta* la risonanza dell'ultimo accordo invece di lasciarla
    dov'è, e il file finisce in un silenzio che negli altri confini di battuta
    non c'è. Misurato: alla giuntura il livello scendeva sotto il minimo di
    tutti gli altri confini.

    Qui il pezzo si suona **tre volte di fila e si ritaglia quella di mezzo**.
    Al primo campione del ritaglio la coda del giro precedente sta ancora
    suonando, e all'ultimo sta suonando la stessa identica coda — perché il
    materiale è periodico e il riverbero è deterministico. Il loop non si
    chiude: non si è mai aperto.
    """
    rng = rng or np.random.default_rng(SEME)
    battuta = 3 * 60.0 / bpm
    n_battute = len(giro) * battute_per_accordo
    durata = n_battute * battuta
    PASSATE = 3
    tr = Traccia(durata * PASSATE, canali=2)

    for passata in range(PASSATE):
        t = passata * durata
        for basso, accordo in giro:
            for _ in range(battute_per_accordo):
                # UNO — il basso, largo e centrato
                tr.mescola(ancia(basso, battuta * 0.34, musette=5.0, corpo=900.0,
                                 attacco=0.022, rilascio=0.10, prof_vib=0.004),
                           t, 0.62, pan=0.0)
                # DUE e TRE — l'accordo, corto, un filo aperto nello stereo
                for k, off in enumerate([battuta / 3, 2 * battuta / 3]):
                    for j, m in enumerate(accordo):
                        tr.mescola(ancia(m, battuta * 0.26, musette=15.0, corpo=2000.0,
                                         attacco=0.014, rilascio=0.07),
                                   t + off,
                                   0.23, pan=(-0.35 + 0.35 * j) * (1 if k == 0 else -1))
                t += battuta

        if melodia:
            for quando, midi, dur in melodia:
                tr.mescola(ancia(midi, dur, musette=11.0, corpo=2700.0,
                                 attacco=0.035, rilascio=0.12),
                           passata * durata + quando * battuta,
                           guadagno_melodia, pan=0.10)

    x = tr.uscita()
    x = np.stack([riverbero(x[:, 0], 0.22, 0.075, rng),
                  riverbero(x[:, 1], 0.22, 0.075, rng)], axis=1)

    n_loop = n_campioni(durata)
    return normalizza(x[n_loop:2 * n_loop], 0.80)


def m_bottega(rng):
    """Bottega Angelini. Lento, nessuna fretta: qui si decide, non si gioca."""
    giro = [DO, LAm, REm, SOL7]
    melodia = [
        (0.00, 72, 0.55), (0.66, 71, 0.30), (1.00, 72, 0.75),
        (2.00, 69, 0.55), (2.66, 67, 0.30), (3.00, 69, 0.75),
        (4.00, 74, 0.55), (4.66, 72, 0.30), (5.00, 71, 0.75),
        (6.00, 67, 1.10),
        (8.00, 72, 0.55), (8.66, 74, 0.30), (9.00, 76, 0.75),
        (10.00, 74, 0.55), (10.66, 72, 0.30), (11.00, 71, 0.75),
        (12.00, 69, 0.55), (12.66, 71, 0.30), (13.00, 72, 0.75),
        (14.00, 72, 1.30),
    ]
    return _valzer(giro, bpm=132, battute_per_accordo=4, melodia=melodia, rng=rng)


def m_menu(rng):
    """Il menu. Lo stesso tema, ma rado: due accordi e molta aria."""
    giro = [DO, SOL7]
    melodia = [
        (0.00, 67, 1.20), (2.00, 72, 1.60),
        (4.00, 71, 1.20), (6.00, 67, 1.90),
    ]
    return _valzer(giro, bpm=112, battute_per_accordo=4, melodia=melodia,
                   guadagno_melodia=0.62, rng=rng)


def m_battaglia(rng):
    """Il tavolo. Stessa armonia, più svelta e in minore: è la stessa sera,
    ma adesso c'è qualcosa in gioco."""
    giro = [LAm, FA, DO, SOL7]
    melodia = [
        (0.00, 69, 0.42), (0.66, 72, 0.28), (1.00, 76, 0.60),
        (2.00, 74, 0.42), (2.66, 72, 0.28), (3.00, 69, 0.60),
        (4.00, 72, 0.42), (4.66, 74, 0.28), (5.00, 72, 0.60),
        (6.00, 67, 1.20),
        # L'ultima battuta non resta vuota: due note che salgono e riportano
        # al La di capo. Senza, il punto di loop suonava più vuoto di tutti
        # gli altri confini di battuta — misurato, non temuto.
        (7.33, 64, 0.30), (7.66, 67, 0.34),
    ]
    return _valzer(giro, bpm=168, battute_per_accordo=2, melodia=melodia,
                   guadagno_melodia=0.50, rng=rng)


MUSICHE = {
    "musica_menu": m_menu,
    "musica_bottega": m_bottega,
    "musica_battaglia": m_battaglia,
}


# ═══════════════════════════════════════════════════════════════════════════
#  Scrittura e verifica
# ═══════════════════════════════════════════════════════════════════════════

def scrivi_wav(path: Path, x: np.ndarray) -> None:
    stereo = x.ndim == 2
    dati = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dati.tobytes())


def scrivi_ogg(path: Path, x: np.ndarray) -> bool:
    """Vorbis via ffmpeg. Godot cicla bene solo l'ogg — l'mp3 lascia un buco."""
    tmp = path.with_suffix(".tmp.wav")
    scrivi_wav(tmp, x)
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
           "-i", str(tmp), "-ac", "2", "-c:a", "vorbis", "-strict", "-2",
           "-b:a", "144k", str(path)]
    esito = subprocess.run(cmd, capture_output=True, text=True)
    tmp.unlink(missing_ok=True)
    if esito.returncode != 0:
        print(f"  ffmpeg ha fallito su {path.name}: {esito.stderr.strip()[:200]}",
              file=sys.stderr)
        return False
    return True


def misura(nome: str, x: np.ndarray) -> dict:
    """Quello che si può controllare senza orecchie.

    Non dice se un suono è bello. Dice se è rotto — e un suono rotto lo è
    sempre in uno di questi cinque modi.
    """
    mono = x if x.ndim == 1 else x.mean(axis=1)
    fin = np.hanning(len(mono)) * mono
    spec = np.abs(np.fft.rfft(fin))
    freqs = np.fft.rfftfreq(len(fin), 1.0 / SR)
    somma = float(np.sum(spec)) or 1.0
    return {
        "nome": nome,
        "durata": len(mono) / SR,
        "canali": 1 if x.ndim == 1 else 2,
        "picco": float(np.max(np.abs(mono))),
        "rms": float(np.sqrt(np.mean(mono ** 2))),
        "dc": float(np.mean(mono)),
        "centroide": float(np.sum(freqs * spec) / somma),
        "clip": int(np.sum(np.abs(mono) >= 0.999)),
        "silenzio_iniziale": float(np.argmax(np.abs(mono) > 0.01) / SR),
    }


def stampa_referto(righe: list[dict]) -> None:
    print(f"{'suono':18} {'dur':>6} {'ch':>3} {'picco':>7} {'rms':>7} "
          f"{'dc':>9} {'centroide':>10} {'clip':>5} {'attacco':>8}")
    print("-" * 82)
    for r in righe:
        allarme = ""
        if r["clip"] > 0:
            allarme += " ⚠clip"
        if abs(r["dc"]) > 0.01:
            allarme += " ⚠dc"
        if r["silenzio_iniziale"] > 0.02:
            allarme += " ⚠ritardo"
        print(f"{r['nome']:18} {r['durata']:6.2f} {r['canali']:3d} "
              f"{r['picco']:7.3f} {r['rms']:7.3f} {r['dc']:+9.5f} "
              f"{r['centroide']:9.0f}Hz {r['clip']:5d} {r['silenzio_iniziale']*1000:6.1f}ms"
              f"{allarme}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=None,
                    help="cartella di destinazione (default: game/audio/ del gioco)")
    ap.add_argument("--referto", action="store_true",
                    help="misura tutto e non scrive niente")
    ap.add_argument("--solo", default=None,
                    help="genera un solo suono o una sola musica, per iterare")
    args = ap.parse_args()

    out = args.out or (Path(__file__).resolve().parent.parent / "game" / "audio")
    if not args.referto:
        out.mkdir(parents=True, exist_ok=True)

    righe = []

    voci = list(SUONI.items())
    brani = list(MUSICHE.items())
    if args.solo:
        voci = [(k, v) for k, v in voci if k == args.solo]
        brani = [(k, v) for k, v in brani if k == args.solo]
        if not voci and not brani:
            print(f"nessun suono chiamato «{args.solo}»", file=sys.stderr)
            return 1

    for nome, fn in voci:
        x = fn(np.random.default_rng(SEME + hash(nome) % 1000))
        righe.append(misura(nome, x))
        if not args.referto:
            scrivi_wav(out / f"{nome}.wav", x)

    for nome, fn in brani:
        x = fn(np.random.default_rng(SEME + hash(nome) % 1000))
        righe.append(misura(nome, x))
        if not args.referto:
            if not scrivi_ogg(out / f"{nome}.ogg", x):
                return 1

    stampa_referto(righe)
    if not args.referto:
        print(f"\nscritti {len(righe)} file in {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
