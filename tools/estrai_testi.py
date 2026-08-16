#!/usr/bin/env python3
"""Costruisce il catalogo delle stringhe da tradurre.

    python3 tools/estrai_testi.py             # riscrive game/i18n/testi.csv
    python3 tools/estrai_testi.py --referto   # dice cosa troverebbe, non scrive
    python3 tools/estrai_testi.py --lingua en # aggiunge una colonna vuota

Il catalogo è un CSV con la chiave nella prima colonna e una colonna per
lingua. La **chiave è la frase italiana**: è così che funziona Godot, che
traduce da solo il testo assegnato a una Label usando la stringa sorgente come
chiave e restituendola invariata se non la trova. Conseguenze, tutte e tre
volute:

  - si traduce **a fette**: le chiavi non ancora nel CSV restano in italiano e
    non rompono niente;
  - l'italiano non ha bisogno di essere tradotto — la colonna `it` esiste solo
    perché un traduttore la legga;
  - **i JSON di game/data/ restano in italiano per sempre.** Tradurli sul posto
    romperebbe il gioco in silenzio: `carte_art.gd` costruisce il nome del file
    del disegno dal nome della carta, e `game_over.gd` ritrova il record da una
    chiave che è anche un'etichetta. Il catalogo è l'unico posto dove sta
    un'altra lingua.

Da dove arrivano le chiavi:

  1. i campi player-facing dei JSON di `game/data/` (le chiavi che cominciano
     per `_` sono commenti per noi e restano fuori);
  2. le stringhe letterali dei `.gd` che finiscono davanti al giocatore,
     riconosciute dalla forma della chiamata;
  3. i **nomi composti delle carte** — «Asso di Picche» non esiste in nessun
     file, nasce unendo valore e seme a runtime. Qui vengono ricomposti con la
     stessa regola di `card.gd`, e `tests/i18n_test.gd` fallisce se le due
     regole divergono.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
DATI = RADICE / "game" / "data"
CODICE = RADICE / "game"
CATALOGO = RADICE / "game" / "i18n" / "testi.csv"

# I campi dei JSON che un giocatore legge. Tutto il resto — id, numeri, pesi,
# percorsi dei file — non si traduce.
CAMPI_VISIBILI = {
    "name", "text", "short", "label", "hint", "testo", "titolo", "nome",
    "subtitle", "best_label", "capitolo", "descrizione",
}

# I campi che sembrano testo ma NON vanno tradotti, con la ragione accanto.
CAMPI_INTOCCABILI = {
    # `best_stat` non è un'etichetta: è la chiave con cui game_over.gd ritrova
    # il valore dentro RunState.stats(). Tradurla fa sparire il record.
    "best_stat",
    "id", "family", "color", "combo_color", "symbol", "portrait", "image",
    "evolves_to", "rank_ids", "suit_ids", "type", "where", "card", "cards",
    "chi", "quando", "evidenzia", "stat", "of", "kind", "requires", "rule",
}

# Come si riconosce una stringa che il giocatore legge.
#
# Elencare le forme di chiamata sembrava piu' preciso e non lo era: il testo
# arriva a schermo per venti strade diverse — una variabile, un elemento di un
# array, un ternario, un dizionario di modelli. Elencandole se ne trovava un
# terzo. Qui si guarda ogni stringa letterale e si scartano quelle che
# **non possono** essere testo: un catalogo con qualche riga di troppo si
# ripulisce a mano in un minuto, uno con dei buchi lascia pezzi di gioco in
# italiano e nessuno se ne accorge finche' non li vede un giocatore.

LETTERALE = re.compile(r'"((?:[^"\\]|\\.)*)"')

# Quello che non e' testo, per forma.
NON_E_TESTO = [
    re.compile(r"^[a-z][a-z0-9_]*$"),               # un id: card_view, deckout
    re.compile(r"^[a-z0-9_]+(\.[a-z0-9_]+)+$"),      # una chiave: battle.speed
    re.compile(r"^(res|user)://"),                   # un percorso
    re.compile(r"^%[-+0-9.]*[sdfx]$"),               # un segnaposto nudo
    re.compile(r"^[^\w]*$"),                         # solo simboli o spazi
    # Uno scheletro di formato non e' una frase: "%s di %s" e "%d / %d" non
    # hanno niente da tradurre. Il nome composto della carta lo mettiamo in
    # catalogo intero ("Asso di Picche"), che e' anche l'unico modo di avere
    # un tedesco decente — "Pik-Ass" non si ottiene riordinando segnaposti.
    re.compile(r"^(%[-+0-9.]*[sdfx]|[\s/:.\-]|%%)+$"),
    # Un numero nudo: e' la sigla di una carta di One. Si vede a schermo ma
    # non cambia lingua, e come chiave sarebbe pericolosa — un traduttore che
    # tocca "1" lo tocca ovunque.
    re.compile(r"^[+\-]?\d+$"),
]
# Righe che non vanno guardate: commenti di documentazione e messaggi da
# console. `push_warning` e `print` parlano a noi, non al giocatore.
SALTA_RIGA = re.compile(r"^\s*(##|#)|push_(error|warning)|printerr|\bprint\(")


def _stringhe_json(valore, campo: str | None = None) -> list[str]:
    """Scende ricorsivamente e raccoglie i campi visibili."""
    out: list[str] = []
    if isinstance(valore, dict):
        for chiave, dentro in valore.items():
            if chiave.startswith("_") or chiave in CAMPI_INTOCCABILI:
                continue
            out += _stringhe_json(dentro, chiave)
    elif isinstance(valore, list):
        for dentro in valore:
            out += _stringhe_json(dentro, campo)
    elif isinstance(valore, str):
        if campo in CAMPI_VISIBILI and valore.strip():
            out.append(valore)
    return out


def dai_json() -> dict[str, list[str]]:
    """Chiave -> in quali file compare."""
    trovate: dict[str, list[str]] = {}
    for percorso in sorted(DATI.glob("*.json")):
        dati = json.loads(percorso.read_text(encoding="utf-8"))
        for s in _stringhe_json(dati):
            trovate.setdefault(s, []).append(percorso.name)
    return trovate


def _puo_essere_testo(s: str) -> bool:
    if len(s.strip()) < 2:
        return False
    for forma in NON_E_TESTO:
        if forma.match(s):
            return False
    # Una frase ha uno spazio, oppure comincia in maiuscolo, oppure ha un
    # accento: sono le tre firme dell'italiano scritto per qualcuno.
    return " " in s or s[0].isupper() or any(c in s for c in "àèéìòùÀÈÉÌÒÙ")


# Chi scrive tr("...") sta DICHIARANDO che quella stringa e' testo. L'euristica
# qui sopra non deve poterlo smentire: senza questa eccezione le etichette di
# una parola sola e minuscola — danni, cura, scudo, oro, veleno, vita — che
# stanno scritte su ogni carta del gioco venivano scartate come se fossero id.
ESPLICITO = re.compile(r"(?:\btr|Testo\.plurale|Testo\.traduci)\s*\(")


def _righe_unite(testo: str):
    """Riunisce i letterali spezzati su piu' righe con `+`.

    `tr("prima meta' " + "seconda meta'")` a runtime cerca in catalogo la frase
    INTERA; leggendo riga per riga in catalogo finiva solo il primo pezzo, e
    quella chiave non ci sarebbe mai stata. Tre paragrafi del glossario delle
    carte sarebbero rimasti in italiano in qualunque lingua.
    """
    fisiche = testo.splitlines()
    i = 0
    while i < len(fisiche):
        riga = fisiche[i]
        prima = i + 1
        while riga.rstrip().endswith("+") and i + 1 < len(fisiche):
            i += 1
            riga = riga.rstrip()[:-1].rstrip() + " " + fisiche[i].strip()
        # Due letterali adiacenti diventano uno solo: "a " "b" -> "a b"
        riga = re.sub(r'"\s*\+\s*"', "", riga)
        yield prima, riga
        i += 1


# Una tabella di etichette — `const EFFECT_LABELS := {"damage": "danni", ...}` —
# sta in cima al file, e il `tr()` che la usa cinquanta righe piu' sotto. Nessuna
# euristica per riga puo' collegare le due cose, e da sole quelle etichette
# sembrano id: minuscole, una parola, senza accenti. Sono pero' le parole
# scritte su OGNI carta del gioco.
#
# Da qui il marcatore: si scrive `# i18n` sopra il blocco e l'estrattore prende
# il valore di ogni riga fino alla graffa che chiude. E' una dichiarazione, non
# un indovinello.
MARCATORE = re.compile(r"#\s*i18n\b", re.IGNORECASE)
VALORE_DI_RIGA = re.compile(r':\s*"((?:[^"\\]|\\.)*)"')


def da_tabelle_marcate() -> dict[str, list[str]]:
    trovate: dict[str, list[str]] = {}
    for percorso in sorted(CODICE.rglob("*.gd")):
        righe = percorso.read_text(encoding="utf-8").splitlines()
        dentro = False
        profondita = 0
        for numero, riga in enumerate(righe, 1):
            if not dentro:
                if MARCATORE.search(riga):
                    dentro = True
                    profondita = 0
                continue
            # La chiusura si riconosce contando le parentesi, non guardando la
            # riga: una tabella di dizionari ha graffe interne, e fermarsi alla
            # prima avrebbe letto solo la prima voce.
            profondita += riga.count("{") + riga.count("[")
            profondita -= riga.count("}") + riga.count("]")
            if profondita <= 0:
                dentro = False
            for trovato in VALORE_DI_RIGA.finditer(riga):
                testo = trovato.group(1)
                if testo.strip():
                    dove = "%s:%d" % (percorso.relative_to(RADICE), numero)
                    trovate.setdefault(testo, []).append(dove)
    return trovate


def dai_gd() -> dict[str, list[str]]:
    trovate: dict[str, list[str]] = {}
    for percorso in sorted(CODICE.rglob("*.gd")):
        for numero, riga in _righe_unite(percorso.read_text(encoding="utf-8")):
            if SALTA_RIGA.search(riga):
                continue
            obbligata = ESPLICITO.search(riga) is not None
            for trovato in LETTERALE.finditer(riga):
                testo = trovato.group(1).replace('\\"', '"').replace("\\n", "\n")
                if obbligata or _puo_essere_testo(testo):
                    if len(testo.strip()) < 1:
                        continue
                    dove = "%s:%d" % (percorso.relative_to(RADICE), numero)
                    trovate.setdefault(testo, []).append(dove)
    return trovate


def nomi_delle_carte() -> dict[str, list[str]]:
    """Ricompone «Asso di Picche» come fa card.gd.

    La regola, copiata da game/logic/card.gd: se il nome del seme e quello del
    valore coincidono la carta ha un nome solo (è una carta fuori seme, tipo il
    Jolly); altrimenti è «<valore> di <seme>». Solo le coppie che esistono
    davvero: `rank_ids` sul seme e `suit_ids` sul valore si limitano a vicenda.
    """
    semi = {v["id"]: v for v in json.loads((DATI / "suits.json").read_text(encoding="utf-8"))}
    valori = {v["id"]: v for v in json.loads((DATI / "ranks.json").read_text(encoding="utf-8"))}

    trovate: dict[str, list[str]] = {}
    for seme in semi.values():
        ammessi = seme.get("rank_ids")
        for valore in valori.values():
            if ammessi is not None and valore["id"] not in ammessi:
                continue
            consentiti = valore.get("suit_ids")
            if consentiti is not None and seme["id"] not in consentiti:
                continue
            # Il vincolo che mancava, ed e' il primo dei tre in card_library:
            # seme e valore devono essere della stessa famiglia. Senza, si
            # generano coppie che nel gioco non esistono — 297 nomi invece
            # dei 153 veri.
            if str(seme.get("family", "")) != str(valore.get("family", "")):
                continue
            nome_seme = str(seme.get("name", "?"))
            nome_valore = str(valore.get("name", "?"))
            nome = nome_seme if nome_seme == nome_valore else "%s di %s" % (nome_valore, nome_seme)
            trovate.setdefault(nome, []).append("%s_%s" % (seme["id"], valore["id"]))
    return trovate


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--referto", action="store_true",
                    help="conta e non scrive niente")
    ap.add_argument("--lingua", action="append", default=[],
                    help="aggiunge una colonna vuota per questa lingua (ripetibile)")
    args = ap.parse_args()

    sorgenti = [
        ("JSON di game/data", dai_json()),
        ("stringhe nei .gd", dai_gd()),
        ("tabelle marcate # i18n", da_tabelle_marcate()),
        ("nomi composti delle carte", nomi_delle_carte()),
    ]

    tutte: dict[str, list[str]] = {}
    for _, trovate in sorgenti:
        for chiave, dove in trovate.items():
            tutte.setdefault(chiave, []).extend(dove)

    print(f"{'sorgente':30} {'chiavi':>8} {'parole':>8}")
    print("-" * 50)
    for nome, trovate in sorgenti:
        parole = sum(len(k.split()) for k in trovate)
        print(f"{nome:30} {len(trovate):8} {parole:8}")
    parole = sum(len(k.split()) for k in tutte)
    print("-" * 50)
    print(f"{'in tutto, senza doppioni':30} {len(tutte):8} {parole:8}")

    # Le lingue già presenti nel catalogo non si perdono quando lo si rigenera:
    # un traduttore che ha riempito mezza colonna non deve ricominciare.
    esistenti: dict[str, dict[str, str]] = {}
    lingue: list[str] = []
    if CATALOGO.exists():
        with CATALOGO.open(encoding="utf-8", newline="") as f:
            lettore = csv.DictReader(f)
            lingue = [c for c in (lettore.fieldnames or []) if c != "keys"]
            for riga in lettore:
                esistenti[riga["keys"]] = riga

    for lingua in args.lingua:
        if lingua not in lingue:
            lingue.append(lingua)
    if "it" not in lingue:
        lingue.insert(0, "it")

    if args.referto:
        nuove = [k for k in tutte if k not in esistenti]
        sparite = [k for k in esistenti if k not in tutte]
        print(f"\nnuove rispetto al catalogo: {len(nuove)}")
        for k in nuove[:12]:
            print("  + " + k[:70])
        if len(nuove) > 12:
            print(f"  … e altre {len(nuove) - 12}")
        print(f"non più usate: {len(sparite)}")
        for k in sparite[:12]:
            print("  - " + k[:70])
        return 0

    CATALOGO.parent.mkdir(parents=True, exist_ok=True)
    with CATALOGO.open("w", encoding="utf-8", newline="") as f:
        scrittore = csv.writer(f)
        scrittore.writerow(["keys"] + lingue)
        for chiave in sorted(tutte):
            riga = [chiave]
            for lingua in lingue:
                if lingua == "it":
                    riga.append(chiave)
                else:
                    riga.append(esistenti.get(chiave, {}).get(lingua, ""))
            scrittore.writerow(riga)

    print(f"\nscritto {CATALOGO.relative_to(RADICE)} — {len(tutte)} chiavi, "
          f"lingue: {', '.join(lingue)}")
    print("Poi: godot --headless --path . --import   (genera i .translation)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
