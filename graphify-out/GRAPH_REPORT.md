# Graph Report - citta-campagna  (2026-08-17)

## Corpus Check
- 20 files · ~2,234,624 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 227 nodes · 412 edges · 24 communities (22 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0d47672f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

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
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]

## God Nodes (most connected - your core abstractions)
1. `ndarray` - 22 edges
2. `n_campioni()` - 19 edges
3. `Traccia` - 19 edges
4. `normalizza()` - 19 edges
5. `ancia()` - 18 edges
6. `riverbero()` - 17 edges
7. `Gli incontri` - 15 edges
8. `legno()` - 14 edges
9. `Città & Campagna — autobattler a carte` - 14 edges
10. `env_perc()` - 13 edges

## Surprising Connections (you probably didn't know these)
- `riverbero()` --calls--> `n_campioni()`  [EXTRACTED]
  tools/genera_audio.py → tools/genera_audio.py  _Bridges community 8 → community 10_
- `scrivi_ogg()` --references--> `ndarray`  [EXTRACTED]
  tools/genera_audio.py → tools/genera_audio.py  _Bridges community 8 → community 17_
- `m_bottega()` --calls--> `_valzer()`  [EXTRACTED]
  tools/genera_audio.py → tools/genera_audio.py  _Bridges community 10 → community 22_
- `m_menu()` --calls--> `_valzer()`  [EXTRACTED]
  tools/genera_audio.py → tools/genera_audio.py  _Bridges community 10 → community 23_

## Import Cycles
- None detected.

## Communities (24 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.50
Nodes (4): Balla fino all'alba, Gioca alla tombola, La sagra di mezz'agosto, Mangia come si deve

### Community 1 - "Community 1"
Cohesion: 0.09
Nodes (21): Asset: cosa entra dove, Città & Campagna — autobattler a carte, Come si vince, Da sapere, File, Fluido non vuol dire tanti fotogrammi, Gaiofanamon, I quattro mazzi (+13 more)

### Community 2 - "Community 2"
Cohesion: 0.40
Nodes (5): Appare un professore selvatico, Prendi il Fuoco, Prendi l'Acqua, Prendi l'Elettro, Prendi l'Erba

### Community 3 - "Community 3"
Cohesion: 0.07
Nodes (29): ○ Acqua, ◼ Bastoni, ■ Blocco, ■ Blu, Briscola — le carte di campagna, ■ Cambia Colore, Come si legge una carta, ● Coppe (+21 more)

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
Cohesion: 0.13
Nodes (41): ndarray, ancia(), carta(), env_adsr(), env_perc(), _fase(), legno(), metallo() (+33 more)

### Community 9 - "Community 9"
Cohesion: 0.50
Nodes (4): L'aziana, Raccoglila e aggiungila al mazzo, Restituiscila alla signora, Sembra da collezione: vendila

### Community 10 - "Community 10"
Cohesion: 0.14
Nodes (31): m_battaglia(), normalizza(), Una stanza piccola — il bar, non la cattedrale.      Non è un riverbero vero: so, Un colpo che va a segno. Legno + un morso in alto, corto., Il colpo che prendi tu: stesso legno, più cupo e più lento., Una carta appoggiata sul tavolo. Il suono più frequente del gioco:     deve esse, Due note d'ancia che salgono: sì., Due note che scendono: no. Stesso gesto rovesciato. (+23 more)

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
Cohesion: 0.29
Nodes (6): Accetta, e ringrazia, Accetta lo scambio, Gli incontri, La colletta, Lo scambio, Rifiuta

### Community 15 - "Community 15"
Cohesion: 0.24
Nodes (12): da_tabelle_marcate(), dai_gd(), dai_json(), main(), nomi_delle_carte(), _puo_essere_testo(), Scende ricorsivamente e raccoglie i campi visibili., Chiave -> in quali file compare. (+4 more)

### Community 16 - "Community 16"
Cohesion: 0.22
Nodes (8): Città & Campagna, Come si avvia, Cosa c'è dentro, I quattro mazzi, Il gioco in cinque righe, Licenza, ▶ [Si gioca qui, nel browser](https://michelinithomas-prog.github.io/citta-campagna/), Sul nome

### Community 17 - "Community 17"
Cohesion: 0.53
Nodes (6): Path, main(), Vorbis via ffmpeg. Godot cicla bene solo l'ogg — l'mp3 lascia un buco., scrivi_ogg(), scrivi_wav(), stampa_referto()

### Community 18 - "Community 18"
Cohesion: 0.67
Nodes (3): Accetta la sfida, Guarda come gioca, Il giocatore

### Community 19 - "Community 19"
Cohesion: 0.67
Nodes (3): Ascoltalo fino in fondo, Dagli una mano nei campi, Il vecchio sull'aia

### Community 20 - "Community 20"
Cohesion: 0.67
Nodes (3): Cerca riparo e aspetta, Il temporale, Tira dritto sotto l'acqua

### Community 21 - "Community 21"
Cohesion: 0.67
Nodes (3): Procedi a passo svelto, Rovista nel bidone, Un problema shockante

## Knowledge Gaps
- **94 isolated node(s):** `Come si vince`, `Le due sconfitte, che sono il gioco`, `La catena di One`, `Gaiofanamon`, `File` (+89 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Gli incontri` connect `Community 14` to `Community 0`, `Community 2`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 11`, `Community 12`, `Community 18`, `Community 19`, `Community 20`, `Community 21`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `ndarray` connect `Community 8` to `Community 17`, `Community 10`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `ancia()` connect `Community 8` to `Community 10`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `Scende ricorsivamente e raccoglie i campi visibili.`, `Chiave -> in quali file compare.`, `Riunisce i letterali spezzati su piu' righe con `+`.      `tr("prima meta' " + "` to the rest of the system?**
  _133 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.09090909090909091 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.06666666666666667 - nodes in this community are weakly interconnected._
- **Should `Community 8` be split into smaller, more focused modules?**
  _Cohesion score 0.1273532668881506 - nodes in this community are weakly interconnected._