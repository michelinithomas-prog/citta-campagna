# Le carte

> Ogni carta è un seme più un valore. Il seme dice cosa fa, il valore quanto fa e quanto si fa aspettare.
>
> Generato da `tools/genera_manuale.gd` — non modificarlo a mano:
> alla prossima rigenerazione le modifiche spariscono. Cambia i JSON in `game/data/`.

## Come si legge una carta

L'effetto non è scritto carta per carta: si **somma**. Il seme dice cosa
sa fare la carta (`effetto = valore × moltiplicatore`), il numero ci
aggiunge il suo — lo stesso su tutti i mazzi — e alcune carte hanno per
giunta un effetto scritto a mano.

Le sigle: **ATT** attacco · **SCU** scudo · **CUR** cura · **VEL** veleno ·
**SAN** sanguinamento · **ORO** oro. Il `+n` finale conta gli effetti che
un numero non ce l'hanno: rubare, paralizzare, allungare la catena.

I *punti al secondo* sono il metro con cui le carte si confrontano fra
loro (`game/logic/budget.gd`): un punto vale un danno, e tutto il resto
— scudo, cura, oro, veleno, tempo rubato — è convertito in quello.


---

# Poker — le carte di città

*Veloci, effetti piccoli. Consumano il mazzo in fretta e vincono per ferite.*

## ♠ Picche

*Colpisce più forte di quanto dovrebbe, e ti presenta il conto.*

Attesa: **2.0s + 0.30s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ♠ A — Asso di Picche | 2 ATT | 2.3s | 0.70 |
| ♠ 2 — Due di Picche | 1 ATT · 1 SAN | 2.6s | 0.85 |
| ♠ 3 — Tre di Picche | 2 ATT · 2 SCU | 2.9s | 1.17 |
| ♠ 4 — Quattro di Picche | 2 ATT · 2 CUR | 3.2s | 1.31 |
| ♠ 5 — Cinque di Picche | 3 ATT · 1 VEL | 4.5s | 1.33 |
| ♠ 6 — Sei di Picche | 4 ATT · +1 | 4.4s | 1.50 |
| ♠ 7 — Sette di Picche | 4 ATT · +1 | 4.5s | 1.60 |
| ♠ 8 — Otto di Picche | 5 ATT · +1 | 4.6s | 1.70 |
| ♠ 9 — Nove di Picche | 5 ATT · +1 | 4.7s | 1.79 |
| ♠ 10 — Dieci di Picche | 11 ATT | 5.2s | 2.12 |
| ♠ J — Fante di Picche | 11 ATT · +1 | 5.6s | 2.96 |
| ♠ Q — Donna di Picche | 7 ATT · +2 | 5.8s | 2.67 |
| ♠ K — Re di Picche | 8 ATT · +2 | 8.3s | 2.99 |

## ♥ Cuori

*Cura e ripara, senza fare rumore.*

Attesa: **2.2s + 0.30s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ♥ A — Asso di Cuori | 1 ATT | 2.5s | 0.64 |
| ♥ 2 — Due di Cuori | 1 SCU · 1 CUR · 1 SAN | 2.8s | 0.79 |
| ♥ 3 — Tre di Cuori | 3 SCU · 1 CUR | 3.1s | 1.10 |
| ♥ 4 — Quattro di Cuori | 1 SCU · 4 CUR | 3.4s | 1.24 |
| ♥ 5 — Cinque di Cuori | 1 SCU · 2 CUR · 1 VEL | 4.7s | 1.28 |
| ♥ 6 — Sei di Cuori | 2 SCU · 3 CUR · +1 | 4.6s | 1.44 |
| ♥ 7 — Sette di Cuori | 2 SCU · 3 CUR · +1 | 4.7s | 1.54 |
| ♥ 8 — Otto di Cuori | 2 SCU · 4 CUR · +1 | 4.8s | 1.63 |
| ♥ 9 — Nove di Cuori | 2 SCU · 4 CUR · +1 | 4.9s | 1.72 |
| ♥ 10 — Dieci di Cuori | 5 ATT · 3 SCU · 5 CUR | 5.4s | 2.05 |
| ♥ J — Fante di Cuori | 3 SCU · 5 CUR · +2 | 5.8s | 2.70 |
| ♥ Q — Donna di Cuori | 3 SCU · 5 CUR · +1 | 6.0s | 2.26 |
| ♥ K — Re di Cuori | 9 SCU · 6 CUR · +1 | 8.5s | 2.90 |

## ♣ Fiori

*Il veleno lavora piano, e non se ne va più.*

Attesa: **4.0s + 0.10s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ♣ A — Asso di Fiori | 1 ATT · 1 SCU · 1 VEL | 4.1s | 1.07 |
| ♣ 2 — Due di Fiori | 1 SCU · 1 VEL · 1 SAN | 4.2s | 1.14 |
| ♣ 3 — Tre di Fiori | 4 SCU · 1 VEL | 4.3s | 1.35 |
| ♣ 4 — Quattro di Fiori | 2 SCU · 2 CUR · 1 VEL | 4.4s | 1.45 |
| ♣ 5 — Cinque di Fiori | 3 SCU · 2 VEL | 5.5s | 1.45 |
| ♣ 6 — Sei di Fiori | 3 SCU · 1 VEL · +1 | 5.2s | 1.62 |
| ♣ 7 — Sette di Fiori | 4 SCU · 1 VEL · +1 | 5.1s | 1.73 |
| ♣ 8 — Otto di Fiori | 4 SCU · 1 VEL · +1 | 5.0s | 1.84 |
| ♣ 9 — Nove di Fiori | 5 SCU · 1 VEL · +1 | 4.9s | 1.96 |
| ♣ 10 — Dieci di Fiori | 5 ATT · 5 SCU · 1 VEL | 5.2s | 2.31 |
| ♣ J — Fante di Fiori | 6 SCU · 1 VEL · +1 | 5.4s | 2.48 |
| ♣ Q — Donna di Fiori | 6 SCU · 1 VEL · +1 | 5.4s | 2.61 |
| ♣ K — Re di Fiori | 7 SCU · 1 VEL · +2 | 7.7s | 3.01 |

## ♦ Quadri

*Non colpisce: potenzia il posto, per chi verrà dopo.*

Attesa: **5.2s + 0.06s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ♦ A — Asso di Quadri | 1 ATT · +1 | 5.3s | 0.83 |
| ♦ 2 — Due di Quadri | 1 ATT · 1 SAN · +1 | 5.3s | 0.88 |
| ♦ 3 — Tre di Quadri | 1 ATT · 2 SCU · +1 | 5.4s | 1.05 |
| ♦ 4 — Quattro di Quadri | 1 ATT · 2 CUR · +1 | 5.4s | 1.14 |
| ♦ 5 — Cinque di Quadri | 2 ATT · 1 VEL · +1 | 6.5s | 1.19 |
| ♦ 6 — Sei di Quadri | 2 ATT · +2 | 6.2s | 1.31 |
| ♦ 7 — Sette di Quadri | 2 ATT · +2 | 6.0s | 1.40 |
| ♦ 8 — Otto di Quadri | 3 ATT · +2 | 5.9s | 1.50 |
| ♦ 9 — Nove di Quadri | 3 ATT · +2 | 5.7s | 1.59 |
| ♦ 10 — Dieci di Quadri | 9 ATT · +1 | 6.0s | 1.92 |
| ♦ J — Fante di Quadri | 4 ATT · +2 | 6.2s | 2.09 |
| ♦ Q — Donna di Quadri | 4 ATT · +2 | 6.1s | 2.21 |
| ♦ K — Re di Quadri | 5 ATT · 4 ORO · +2 | 8.4s | 3.29 |

## ◎ Jolly

*Non ha un seme e non ne vuole: prende la carta più imminente dell'avversario e si mette al suo posto.*

Attesa: **4.0s + 0.00s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ◎ ★ — Jolly | +1 | 4.0s | 2.00 |


---

# Briscola — le carte di campagna

*Lente, effetti grossi. Consumano poco mazzo e vincono per esaurimento.*

## ▲ Spade

*Passa attraverso lo scudo e lascia la ferita aperta.*

Attesa: **4.5s + 0.60s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ▲ A — Asso di Spade | 2 ATT | 4.3s | 0.57 |
| ▲ 2 — Due di Spade | 3 ATT · 3 SAN | 5.7s | 1.22 |
| ▲ 3 — Tre di Spade | 4 ATT · 4 SCU · 1 SAN | 6.3s | 1.23 |
| ▲ 4 — Quattro di Spade | 5 ATT · 4 CUR · 1 SAN | 6.9s | 1.42 |
| ▲ 5 — Cinque di Spade | 7 ATT · 2 SCU · 1 VEL · 1 SAN | 8.3s | 1.51 |
| ▲ 6 — Sei di Spade | 8 ATT · 2 SAN · +1 | 8.9s | 1.76 |
| ▲ 7 — Sette di Spade | 9 ATT · 2 SAN · +1 | 9.3s | 1.88 |
| ▲ F — Fante di Spade | 22 ATT · 2 SAN · +1 | 10.1s | 3.05 |
| ▲ C — Cavallo di Spade | 12 ATT · 2 SAN · +2 | 10.9s | 2.60 |
| ▲ R — Re di Spade | 18 ATT · 3 SAN · +2 | 12.1s | 2.76 |

## ● Coppe

*Cura tanto, e ripesca quello che avevi già buttato.*

Attesa: **6.5s + 0.20s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ● A — Asso di Coppe | 1 ATT · 1 CUR · +1 | 5.9s | 0.85 |
| ● 2 — Due di Coppe | 2 CUR · 2 SAN · +1 | 6.9s | 1.16 |
| ● 3 — Tre di Coppe | 4 SCU · 3 CUR · +1 | 7.1s | 1.29 |
| ● 4 — Quattro di Coppe | 8 CUR · +1 | 7.3s | 1.45 |
| ● 5 — Cinque di Coppe | 2 SCU · 6 CUR · 1 VEL · +1 | 8.3s | 1.51 |
| ● 6 — Sei di Coppe | 7 CUR · +2 | 8.5s | 1.76 |
| ● 7 — Sette di Coppe | 8 CUR · +2 | 8.5s | 1.87 |
| ● F — Fante di Coppe | 1 ATT · 9 CUR · +2 | 8.9s | 2.01 |
| ● C — Cavallo di Coppe | 10 CUR · +2 | 9.3s | 2.25 |
| ● R — Re di Coppe | 5 ATT · 11 CUR · +3 | 10.1s | 2.96 |

## ◼ Bastoni

*Allunga i tempi degli altri, e li rende più piccoli.*

Attesa: **5.0s + 0.55s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ◼ A — Asso di Bastoni | 1 ATT · +2 | 4.8s | 0.48 |
| ◼ 2 — Due di Bastoni | 2 SAN · +2 | 6.1s | 0.92 |
| ◼ 3 — Tre di Bastoni | 4 SCU · +2 | 6.7s | 1.07 |
| ◼ 4 — Quattro di Bastoni | 4 CUR · +2 | 7.2s | 1.22 |
| ◼ 5 — Cinque di Bastoni | 2 SCU · 1 VEL · +2 | 8.6s | 1.30 |
| ◼ 6 — Sei di Bastoni | +3 | 9.1s | 1.52 |
| ◼ 7 — Sette di Bastoni | +3 | 9.5s | 1.60 |
| ◼ F — Fante di Bastoni | 1 ATT · +3 | 10.2s | 1.71 |
| ◼ C — Cavallo di Bastoni | +3 | 10.9s | 1.89 |
| ◼ R — Re di Bastoni | 5 ATT · +4 | 12.1s | 2.31 |

## ◆ Denari

*Oro vero, e una botta.*

Attesa: **5.0s + 0.55s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ◆ A — Asso di Denari | 2 ATT | 4.8s | 0.51 |
| ◆ 2 — Due di Denari | 1 ATT · 2 SAN · 1 ORO | 6.1s | 0.95 |
| ◆ 3 — Tre di Denari | 2 ATT · 4 SCU · 1 ORO | 6.7s | 1.11 |
| ◆ 4 — Quattro di Denari | 3 ATT · 4 CUR · 1 ORO | 7.2s | 1.28 |
| ◆ 5 — Cinque di Denari | 4 ATT · 2 SCU · 1 VEL · 2 ORO | 8.6s | 1.36 |
| ◆ 6 — Sei di Denari | 4 ATT · 2 ORO · +1 | 9.1s | 1.58 |
| ◆ 7 — Sette di Denari | 5 ATT · 2 ORO · +1 | 9.5s | 1.67 |
| ◆ F — Fante di Denari | 7 ATT · 3 ORO · +1 | 10.2s | 1.78 |
| ◆ C — Cavallo di Denari | 6 ATT · 3 ORO · +1 | 10.9s | 1.97 |
| ◆ R — Re di Denari | 12 ATT · 9 ORO · +1 | 12.1s | 2.89 |


---

# Gaiofanamon — le creature che crescono

*Si comprano solo di livello uno. Ogni volta che si attivano crescono e finiscono negli scarti, e **la crescita resta per il resto della partita**: un cucciolo comprato adesso è un veterano fra due round.*

## ○ Acqua

*Lava via quello che rode: veleno e sanguinamento se ne vanno.*

Attesa: **3.4s + 0.30s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ○ I — Sgorga | 4 CUR · +1 | 4.6s | 1.43 |
| ○ II — Sgorga Da Bon | 7 CUR · +1 | 5.5s | 1.69 |
| ○ III — E' Canon | 10 CUR · +1 | 6.4s | 1.88 |

## ◇ Elettro

*Ferma il tempo sulla carta avversaria più vicina a partire.*

Attesa: **3.4s + 0.30s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ◇ I — Sorc | 3 ATT · +1 | 4.6s | 1.22 |
| ◇ II — Rataz | 5 ATT · +1 | 5.5s | 1.78 |

## ▼ Fuoco

*Accorcia l'attesa di tutte le altre tue carte in campo.*

Attesa: **3.4s + 0.30s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ▼ I — Scintela | 4 ATT · +1 | 4.6s | 1.22 |
| ▼ II — Fughett | 6 ATT · +1 | 5.5s | 1.78 |
| ▼ III — E' dragh | 9 ATT · +1 | 6.4s | 2.19 |

## ▽ Erba

*Semina: mette in cima al mazzo un Germoglio, che cura finché resta in campo.*

Attesa: **3.4s + 0.30s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ▽ I — Zappin | 3 CUR · +1 | 4.6s | 1.28 |
| ▽ II — Zappoun | 6 CUR · +1 | 5.5s | 1.46 |
| ▽ III — Zappador | 8 CUR · +1 | 6.4s | 1.59 |

## ▽ Germoglio

*Non colpisce e non si sbriga: sta in campo e ti cura, un poco per ogni secondo.*

Attesa: **14.0s + 0.00s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ▽ ~ — Germoglio |  | 14.0s | 1.80 |

## ◎ L'antigh

*Il vecchio del posto. Quando si sveglia mette nel mazzo una creatura di livello uno, e non si sa quale.*

Attesa: **6.0s + 0.00s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ◎ ◎ — L'antigh | 6 CUR · +1 | 6.0s | 1.40 |


---

# One — quattro colori

*Nessun colore ha un potere suo: quello che conta è la catena. Ogni volta che la carta che entra ha lo stesso colore o lo stesso numero di quella appena uscita, tutto il lato colpisce, cura e ripara di più.*

## ■ Rosso

*Un colore, e nient'altro: quello che la carta fa lo dice il numero. Il colore serve alla catena.*

Attesa: **3.2s + 0.35s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ■ 1 — Uno di Rosso | 2 ATT | 3.6s | 0.69 |
| ■ 2 — Due di Rosso | 1 ATT · 2 SAN | 3.9s | 1.00 |
| ■ 3 — Tre di Rosso | 1 ATT · 4 SCU | 4.2s | 1.07 |
| ■ 4 — Quattro di Rosso | 2 ATT · 4 CUR | 4.6s | 1.17 |
| ■ 5 — Cinque di Rosso | 2 ATT · 3 SCU · 1 VEL | 5.5s | 1.38 |
| ■ 6 — Sei di Rosso | 3 ATT · 3 CUR · +1 | 5.8s | 1.45 |
| ■ 7 — Sette di Rosso | 3 ATT · +1 | 6.1s | 1.51 |
| ■ 8 — Otto di Rosso | 6 ATT · +1 | 6.3s | 1.84 |
| ■ 9 — Nove di Rosso | 4 ATT · +1 | 6.5s | 1.99 |
| ■ 0 — Zero di Rosso | 16 ATT | 7.3s | 2.12 |
| ■ +2 — Pesca Due di Rosso | 5 ATT · +2 | 10.7s | 2.53 |

## ■ Giallo

*Un colore, e nient'altro: quello che la carta fa lo dice il numero. Il colore serve alla catena.*

Attesa: **3.2s + 0.35s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ■ 1 — Uno di Giallo | 2 ATT | 3.6s | 0.69 |
| ■ 2 — Due di Giallo | 1 ATT · 2 SAN | 3.9s | 1.00 |
| ■ 3 — Tre di Giallo | 1 ATT · 4 SCU | 4.2s | 1.07 |
| ■ 4 — Quattro di Giallo | 2 ATT · 4 CUR | 4.6s | 1.17 |
| ■ 5 — Cinque di Giallo | 2 ATT · 3 SCU · 1 VEL | 5.5s | 1.38 |
| ■ 6 — Sei di Giallo | 3 ATT · 3 CUR · +1 | 5.8s | 1.45 |
| ■ 7 — Sette di Giallo | 3 ATT · +1 | 6.1s | 1.51 |
| ■ 8 — Otto di Giallo | 6 ATT · +1 | 6.3s | 1.84 |
| ■ 9 — Nove di Giallo | 4 ATT · +1 | 6.5s | 1.99 |
| ■ 0 — Zero di Giallo | 16 ATT | 7.3s | 2.12 |
| ■ +2 — Pesca Due di Giallo | 5 ATT · +2 | 10.7s | 2.53 |

## ■ Verde

*Un colore, e nient'altro: quello che la carta fa lo dice il numero. Il colore serve alla catena.*

Attesa: **3.2s + 0.35s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ■ 1 — Uno di Verde | 2 ATT | 3.6s | 0.69 |
| ■ 2 — Due di Verde | 1 ATT · 2 SAN | 3.9s | 1.00 |
| ■ 3 — Tre di Verde | 1 ATT · 4 SCU | 4.2s | 1.07 |
| ■ 4 — Quattro di Verde | 2 ATT · 4 CUR | 4.6s | 1.17 |
| ■ 5 — Cinque di Verde | 2 ATT · 3 SCU · 1 VEL | 5.5s | 1.38 |
| ■ 6 — Sei di Verde | 3 ATT · 3 CUR · +1 | 5.8s | 1.45 |
| ■ 7 — Sette di Verde | 3 ATT · +1 | 6.1s | 1.51 |
| ■ 8 — Otto di Verde | 6 ATT · +1 | 6.3s | 1.84 |
| ■ 9 — Nove di Verde | 4 ATT · +1 | 6.5s | 1.99 |
| ■ 0 — Zero di Verde | 16 ATT | 7.3s | 2.12 |
| ■ +2 — Pesca Due di Verde | 5 ATT · +2 | 10.7s | 2.53 |

## ■ Blu

*Un colore, e nient'altro: quello che la carta fa lo dice il numero. Il colore serve alla catena.*

Attesa: **3.2s + 0.35s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ■ 1 — Uno di Blu | 2 ATT | 3.6s | 0.69 |
| ■ 2 — Due di Blu | 1 ATT · 2 SAN | 3.9s | 1.00 |
| ■ 3 — Tre di Blu | 1 ATT · 4 SCU | 4.2s | 1.07 |
| ■ 4 — Quattro di Blu | 2 ATT · 4 CUR | 4.6s | 1.17 |
| ■ 5 — Cinque di Blu | 2 ATT · 3 SCU · 1 VEL | 5.5s | 1.38 |
| ■ 6 — Sei di Blu | 3 ATT · 3 CUR · +1 | 5.8s | 1.45 |
| ■ 7 — Sette di Blu | 3 ATT · +1 | 6.1s | 1.51 |
| ■ 8 — Otto di Blu | 6 ATT · +1 | 6.3s | 1.84 |
| ■ 9 — Nove di Blu | 4 ATT · +1 | 6.5s | 1.99 |
| ■ 0 — Zero di Blu | 16 ATT | 7.3s | 2.12 |
| ■ +2 — Pesca Due di Blu | 5 ATT · +2 | 10.7s | 2.53 |

## ■ Cambia Colore

*Sta bene con qualunque colore: dovunque la metti, la catena continua. Numero non ne ha, quindi da quella parte non lega niente.*

Attesa: **5.0s + 0.00s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ■ ◎ — Cambia Colore | +1 | 5.0s | 1.60 |

## ■ Pesca Quattro

*Quattro anelli di catena in un colpo solo, e quattro carte in meno all'avversario. Il prezzo è un Blocco nel tuo mazzo: prima o poi uscirà, e quel giorno la catena si spegne.*

Attesa: **15.0s + 0.00s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ■ +4 — Pesca Quattro | +3 | 15.0s | 3.13 |

## ■ Blocco

*Nel mazzo ci finisce in un modo solo: ce l'hai messa tu, giocando un Pesca Quattro. Quando entra in campo la catena si spegne.*

Attesa: **3.0s + 0.00s per punto di valore**

| Carta | Cosa fa | Attesa | Punti al secondo |
|---|---|---|---|
| ■ X — Blocco | +1 | 3.0s | -2.67 |


---

## Le carte con carattere

Queste hanno un effetto in più (o al posto di) quello del seme.

| Carta | Cosa fa in più |
|---|---|
| **Re di Picche** | Colpisce e brucia la carta avversaria più vicina a partire. |
| **Donna di Picche** | Colpisce e dà una spinta di un secondo alle tue altre carte. |
| **Fante di Picche** | Colpisce due volte: una piena e una da quattro. |
| **Re di Cuori** | Cura e lascia sei di scudo. |
| **Fante di Cuori** | Cura poco, ma torna in fondo al mazzo una volta. |
| **Re di Fiori** | Fa scudo e impasta le carte avversarie per un secondo e mezzo. |
| **Re di Quadri** | Il conto torna: quattro monete in più. |
| **Re di Spade** | Il colpo più pesante del mazzo, e porta via anche una carta. |
| **Cavallo di Spade** | Carica: colpisce e affretta di due secondi le tue altre carte. |
| **Fante di Spade** | Metà delle volte raddoppia il colpo. |
| **Re di Coppe** | Cura tanto e torna in fondo al mazzo: due volte. |
| **Re di Bastoni** | Scudo massiccio, e due secondi di attesa in più per l'avversario. |
| **Re di Denari** | Paga bene: cinque monete oltre al resto. |
| **Sgorga** | Uno sputo d'acqua pulita: si porta via veleno e sanguinamento, e rimette in sesto. |
| **Sgorga Da Bon** | Ha imparato a mirare. Lava via quello che rode e cura il doppio di prima. |
| **E' Canon** | Due cannoni sulla schiena: niente ti resta addosso, e la vita torna su. |
| **Zappin** | Pianta un Germoglio in cima al mazzo, e intanto cura un poco. |
| **Zappoun** | Il bocciolo si è aperto: semina come prima e cura di più. |
| **Zappador** | Il fiore è grande quanto lui. Semina e ti rimette in piedi. |
| **Scintela** | Una scintilla che non sta ferma: colpisce e dà una spinta alle tue altre carte. |
| **Fughett** | Colpisce più forte, e accorcia l'attesa di tutto il resto. |
| **E' dragh** | Ali, fuoco e fretta: picchia da veterano e manda avanti la fila. |
| **Sorc** | Sta nei bidoni e morde le prese. Ferma la carta avversaria più vicina a partire. |
| **Rataz** | Cresciuto male e di cattivo umore: paralizza più a lungo e picchia di più. |
