# Città & Campagna

Autobattler a carte in Godot 4.6. Bottega → battaglia automatica → round successivo:
il giocatore decide solo fra una battaglia e l'altra, la battaglia si guarda.

Progetto Godot autonomo, in italiano, senza dipendenze né addon. **375 test verdi**
(stato al 17 agosto 2026).

---

## Il gioco in cinque righe

Cinque carte per lato, ognuna con la sua attesa. Quando l'attesa finisce la carta fa
il suo effetto, viene scartata e rimpiazzata pescando dal mazzo. **Il mazzo non si
rimescola mai**: se devi rimpiazzare e la pila è vuota, hai perso. Si perde anche con
gli HP a zero — sono le due sconfitte, ed è lì che sta il bilanciamento.

Si vince con **dieci vittorie prima di finire le dieci vite**. Chi perde ritrova
davanti lo stesso avversario: è il conto delle vittorie a farlo avanzare, non quello
delle partite. Perdere presto costa una vita, perdere tardi ne costa tre.

## I quattro mazzi

Si mescolano tutti nello stesso mazzo del giocatore.

| mazzo | ritmo | come si riconosce |
|---|---|---|
| **poker** (♠♥♣♦) | veloce, effetti piccoli | vince per HP. Cuori e Quadri sono rosse: entrano nella catena di One |
| **briscola** (▲●◼◆) | lento, effetti grossi | consuma poco mazzo, vince per esaurimento |
| **one** (■ in quattro colori) | medio | fa partire la catena |
| **gaiofanamon** (○◇▼▽) | medio | si attivano, crescono di livello e vanno negli scarti |

Il seme dice cosa sa fare la carta, il numero ci aggiunge il suo (1 danno · 2
sanguinamento · 3 scudo · 4 cura · 5 veleno · 6 potenzia lo slot · 7 indebolisce ·
8 recupera · 9 scarta dal mazzo altrui · 10 grosso e lento · J rallenta · Q lifesteal ·
K +danni fino a fine match).

**La catena di One**: quando una carta lascia uno slot e quella che entra le somiglia
— stesso colore o stesso numero — la catena si allunga, e da lì in poi tutto il lato
colpisce, cura e ripara di più. Non cala mai da sola. A decidere è il mazzo della
carta che *esce* dallo slot; chi entra può arrivare da qualunque mazzo.

Sopra ci stanno **reliquie**, **innesti**, **eventi** e dieci avversari con i loro
dialoghi: `docs/` li racconta uno per uno.

## Come si avvia

Serve [Godot 4.6](https://godotengine.org/) (nessun addon, nessuna dipendenza).

```bash
godot --path .                                          # si gioca
godot --headless --path . --import                      # solo la prima volta
godot --headless --path . --script res://core/tests/run_tests.gd   # 375 test
```

In gioco: `F1` overlay · `F2` console comandi · `F5` ricarica dati e tema a caldo ·
`F8` rigioca lo stesso seed · `F9` screenshot · `ESC` pausa.

Per la build web, `export_presets.cfg` ha già il preset HTML5 pronto
(`godot --headless --path . --export-release "Web" build/web/index.html`, poi si
serve quella cartella con un qualsiasi server statico).

## Cosa c'è dentro

```
core/          logica pura senza nodi (StatBlock, Wallet, SimClock, EffectResolver,
               RngStream), autoload (Events, Cfg, Rng, Content, Save, Audio, Ui,
               Router, Dbg), tema e palette, runner dei test
game/logic/    le regole del gioco, senza UI: duel, market, run_state, card_library…
game/data/     tutti i contenuti in JSON — carte, semi, valori, reliquie, eventi,
               avversari, dialoghi, bilanciamento (tuning.json)
game/art/      ~60 MB di disegni: carte, personaggi, gaiofanamon, eventi, sfondi,
               finali, reliquie, UI
game/audio/    tre musiche (menu, bottega, battaglia) + gli effetti
game/i18n/     i testi estratti, traducibili
game/ui/       i componenti visivi, scritti in codice
tests/         la suite del gioco (bilanciamento compreso)
tools/         script di servizio: diagnosi carte ed economia, screenshot automatici,
               registrazione battaglie, misure di fluidità, generatore del manuale
docs/          carte, avversari, eventi, reliquie e innesti raccontati a parole
graphify-out/  grafo di conoscenza del progetto (apri graph.html nel browser)
CLAUDE.md      il documento di design vero e proprio: regole, numeri, trappole
```

Tre regole tengono in piedi il resto: **la logica non conosce la UI**, **i contenuti
stanno nei JSON**, **niente casualità fuori da `Rng`** (mai `randi()` o `shuffle()`:
romperebbero il determinismo, e con esso i test e la possibilità di riprodurre un bug
con lo stesso seed).

## Sul nome

Dal 17 agosto 2026 il gioco prosegue come **Auto-Briscola**, in un progetto
ristrutturato su mappa a zone. *Città & Campagna* è il nome di tutto quello che è
stato fatto prima, questo repo compreso: qui dentro non è stato rinominato niente, ed
è voluto.

Questa è una copia congelata e autonoma: `core/` è una cartella vera e non un symlink
al core condiviso del monorepo di origine, così il progetto resta avviabile e verde
anche dopo che quel core cambierà.

## Licenza

Nessuna licenza aperta: tutti i diritti riservati. Repo privato di lavoro.
