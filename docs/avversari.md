# Gli avversari

> Uno per vittoria. Chi perde se lo ritrova davanti: è il conteggio delle vittorie a farli avanzare.
>
> Generato da `tools/genera_manuale.gd` — non modificarlo a mano:
> alla prossima rigenerazione le modifiche spariscono. Cambia i JSON in `game/data/`.

Nessuno di loro gioca *un* mazzo — finiscono tutti nello stesso — ma
ognuno ha una preferenza forte, e si riconosce dopo dieci secondi di
battaglia. Le percentuali qui sotto sono i pesi con cui pesca le carte.

| # | Avversario | Vita | Scudo | Mazzo | Valori | Poker | Briscola | One | Gaiofanamon |
|---:|---|---:|---:|---:|:---:|---:|---:|---:|---:|
| 1 | **Il Baro** | 34 | 0 | 18 | 2-7 | 55% | 10% | 30% | 5% |
| 2 | **L'Oste** | 46 | 4 | 20 | 3-8 | 20% | 50% | 20% | 10% |
| 3 | **Il Vecchio Contadino** | 48 | 0 | 22 | 3-8 | 10% | 65% | 5% | 20% |
| 4 | **Il Fabbro** | 52 | 4 | 20 | 3-8 | 35% | 45% | 5% | 15% |
| 5 | **Il Signorotto** | 55 | 6 | 20 | 6-11 | 50% | 15% | 30% | 5% |
| 6 | **La Ladra** | 56 | 0 | 24 | 4-10 | 20% | 10% | 55% | 15% |
| 7 | **L'Ubriacone** | 60 | 0 | 24 | 2-11 | 25% | 20% | 45% | 10% |
| 8 | **La Vecchia** | 64 | 6 | 22 | 4-11 | 10% | 15% | 15% | 60% |
| 9 | **Il Professore** | 72 | 8 | 24 | 5-11 | 10% | 5% | 15% | 70% |
| 10 | **Melon Husk** | 84 | 10 | 28 | 5-13 | 30% | 25% | 25% | 20% |


---

## Il Baro

> Coppola e sorriso storto. Ti rompe il ritmo, e mentre riprendi fiato ti mette giù una figura.


---

## L'Oste

> Non fa niente di speciale. Continua solo a mettere sul tavolo carte che rendono più di quanto costano, finché non ti accorgi che stai perdendo.


---

## Il Vecchio Contadino

> Gioca carte piccole, e le carte piccole gli valgono più di quello che c'è scritto sopra. Più dura la partita, più diventano efficienti.

- le sue carte hanno un bonus: `{"family":"briscola","value_add":2.0}`

---

## Il Fabbro

> Non ha le carte più forti: ha le stesse carte di tutti, temperate meglio. Un Sei di Bastoni con due innesti sopra è un'altra cosa.

- una carta ogni 2 porta 2 innesti, presi fra: affilato, svelto, eco, ferrato, pesante

---

## Il Signorotto

> Panciotto viola e un piano preciso. Figure e carte alte, una dietro l'altra, e One quel tanto che basta a comprarsi il tempo.


---

## La Ladra

> Non fa tantissimo male. È che non ti lascia giocare: quando tocca a te, non tocca a te.


---

## L'Ubriacone

> Non sa nemmeno lui cosa sta facendo, ed è esattamente il motivo per cui non riesci a prevederlo.

- una carta ogni 3 porta 1 innesto, presi fra: eco, melassa, sprone, fionda, borsello

---

## La Vecchia

> Parte con poco e continua a far crescere quello che ha. Nei primi secondi è debole; se la lasci giocare, non lo è più.


---

## Il Professore

> Capelli bianchi e le linee evolutive imparate a memoria. Non improvvisa: costruisce, e quando ha finito di costruire hai già perso.


---

## Melon Husk

> Non gioca un mazzo: li gioca tutti. Il poker per chiudere, la briscola per restare in piedi, One per non farti giocare e le creature per crescere mentre tu stai fermo.

- le sue carte hanno un bonus: `{"tag":"figura","value_add":2.0}`
- una carta ogni 4 porta 1 innesto, presi fra: affilato, svelto, eco
