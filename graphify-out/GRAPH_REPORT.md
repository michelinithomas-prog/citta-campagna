# Graph Report - cittacampagna  (2026-08-09)

## Corpus Check
- 17 files · ~2,004,173 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 115 nodes · 110 edges · 15 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]

## God Nodes (most connected - your core abstractions)
1. `Gli incontri` - 15 edges
2. `Città & Campagna — autobattler a carte` - 12 edges
3. `Gli avversari` - 11 edges
4. `One — quattro colori` - 9 edges
5. `Gaiofanamon — le creature che crescono` - 7 edges
6. `Poker — le carte di città` - 6 edges
7. `Briscola — le carte di campagna` - 5 edges
8. `Appare un professore selvatico` - 5 edges
9. `L'osteria sulla via` - 4 edges
10. `La bottega del fabbro` - 4 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (15 total, 0 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.10
Nodes (19): Accetta, e ringrazia, Accetta la sfida, Ascoltalo fino in fondo, Balla fino all'alba, Cerca riparo e aspetta, Dagli una mano nei campi, Gioca alla tombola, Gli incontri (+11 more)

### Community 1 - "Community 1"
Cohesion: 0.11
Nodes (17): Asset: cosa entra dove, Città & Campagna — autobattler a carte, Come si vince, Da sapere, File, Gaiofanamon, I quattro mazzi, Il metro del bilanciamento (+9 more)

### Community 2 - "Community 2"
Cohesion: 0.40
Nodes (5): Appare un professore selvatico, Prendi il Fuoco, Prendi l'Acqua, Prendi l'Elettro, Prendi l'Erba

### Community 3 - "Community 3"
Cohesion: 0.14
Nodes (13): ◼ Bastoni, Briscola — le carte di campagna, Come si legge una carta, ● Coppe, ♥ Cuori, ◆ Denari, ♣ Fiori, ◎ Jolly (+5 more)

### Community 4 - "Community 4"
Cohesion: 0.40
Nodes (4): Attenzione a due di queste, Innesti, Reliquie, Reliquie e innesti

### Community 5 - "Community 5"
Cohesion: 0.67
Nodes (3): Compra quello che puoi, La fiera del paese, Vendi quello che hai

### Community 6 - "Community 6"
Cohesion: 0.50
Nodes (4): Chiedigli qualcosa di più fino, Fatti affilare una carta, La bottega del fabbro, Vendigli il ferro vecchio

### Community 7 - "Community 7"
Cohesion: 0.50
Nodes (4): Compra quello che tiene sotto il banco, Il banco dei pegni, Impegna due carte, Tira via dritto

### Community 8 - "Community 8"
Cohesion: 0.22
Nodes (9): ■ Blocco, ■ Blu, ■ Cambia Colore, ■ Giallo, Le carte con carattere, One — quattro colori, ■ Pesca Quattro, ■ Rosso (+1 more)

### Community 9 - "Community 9"
Cohesion: 0.50
Nodes (4): L'aziana, Raccoglila e aggiungila al mazzo, Restituiscila alla signora, Sembra da collezione: vendila

### Community 10 - "Community 10"
Cohesion: 0.29
Nodes (7): ○ Acqua, ◇ Elettro, ▽ Erba, ▼ Fuoco, Gaiofanamon — le creature che crescono, ▽ Germoglio, ◎ L'antigh

### Community 11 - "Community 11"
Cohesion: 0.50
Nodes (4): L'osteria sulla via, Mangia e riposa, Paga da bere a tutti, Sta' a sentire i discorsi

### Community 12 - "Community 12"
Cohesion: 0.67
Nodes (3): Scegli l'autobriscola, Scegli lei, Una scelta difficile

### Community 13 - "Community 13"
Cohesion: 0.17
Nodes (11): Gli avversari, Il Baro, Il Fabbro, Il Professore, Il Signorotto, Il Vecchio Contadino, L'Oste, L'Ubriacone (+3 more)

### Community 14 - "Community 14"
Cohesion: 0.67
Nodes (3): Accetta lo scambio, Lo scambio, Rifiuta

## Knowledge Gaps
- **83 isolated node(s):** `Come si vince`, `Le due sconfitte, che sono il gioco`, `La catena di One`, `Gaiofanamon`, `File` (+78 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Gli incontri` connect `Community 0` to `Community 2`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 11`, `Community 12`, `Community 14`?**
  _High betweenness centrality (0.173) - this node is a cross-community bridge._
- **Why does `One — quattro colori` connect `Community 8` to `Community 3`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `Appare un professore selvatico` connect `Community 2` to `Community 0`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **What connects `Come si vince`, `Le due sconfitte, che sono il gioco`, `La catena di One` to the rest of the system?**
  _83 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._