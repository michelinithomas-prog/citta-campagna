# Città & Campagna — autobattler a carte

Bottega → battaglia automatica → round successivo. Il giocatore decide solo fra
una battaglia e l'altra: la battaglia si guarda.

Cinque carte per lato, ognuna con la sua attesa. Quando l'attesa finisce la
carta fa il suo effetto, viene scartata e rimpiazzata pescando dal mazzo.
**Il mazzo non si rimescola mai**: se devi rimpiazzare e la pila è vuota, hai
perso. Si perde anche con gli HP a zero.

## Come si vince

**Dieci vittorie prima di finire le vite.** Non è una corsa a otto round: si
gioca finché non si arriva a `player.wins_to_win`, e chi perde **ritrova davanti
lo stesso avversario** — è il conto delle vittorie a farlo avanzare, non quello
delle partite.

Le vite sono dieci, ma non costano tutte uguale: perdere presto vale una vita,
perdere tardi ne vale tre (`player.life_cost`, una voce per battaglia giocata).

## Le due sconfitte, che sono il gioco

Il numero da sorvegliare è uno: **il danno erogabile in una battaglia deve stare
intorno agli HP avversari**. Se va molto sopra si vince sempre per HP e metà del
gioco sparisce; se va sotto, ogni battaglia si decide sul conteggio delle carte.
`tests/balance_test.gd` esiste per accorgersene prima del pubblico.

## I quattro mazzi

Si mescolano tutti nello stesso mazzo del giocatore. Una riga per mazzo in
`game/data/families.json`: nome, colore, quanto spesso compare in bottega
(`default_weight`), quanto costa (`price_multiplier`), se è comprabile
(`in_pool`).

| mazzo | ritmo | come si riconosce |
|---|---|---|
| **poker** (♠♥♣♦) | veloce, effetti piccoli | vince per HP. Cuori e Quadri sono **rosse**: entrano nella catena di One |
| **briscola** (▲●◼◆) | lento, effetti grossi | consuma poco mazzo, vince per esaurimento |
| **one** (■ in quattro colori) | medio | la **catena**: vedi sotto |
| **gaiofanamon** (○◇▼▽) | medio | si attivano, **crescono di livello** e vanno negli scarti |

**Il seme dice cosa sa fare la carta, il numero ci aggiunge il suo.** Il tema dei
numeri è lo stesso su poker, briscola e One (1 danno · 2 sanguinamento ·
3 scudo · 4 cura · 5 veleno · 6 potenzia lo slot · 7 indebolisce · 8 recupera ·
9 scarta dal mazzo altrui · 10 grosso e lento · J rallenta · Q lifesteal ·
K +danni fino a fine match). Vive in `ranks.json` come **costanti esplicite**,
non come formule: una riga per valore sono manopole indipendenti, una formula no.

### La catena di One

Quando una carta lascia uno slot e quella che entra le somiglia — **stesso
colore o stesso numero** — la catena si allunga, e da lì in poi *tutto il lato*
colpisce, cura e ripara di più (`battle.combo_step`). Non cala mai da sola.

**La direzione conta, ed è la regola che tiene in piedi tutto il resto**: la
catena la fa partire One, quindi a decidere è il mazzo della carta che **esce**
dallo slot (`"combo": true` in `families.json`). Chi entra può arrivare da
qualunque mazzo — una Cuori si aggancia a un Rosso di One, ed è la ragione per
cui un mazzo di catena tiene volentieri qualche figura di poker.

Senza quel vincolo la catena partiva **da sola nel primo round**: il Baro gioca
poker, il poker ha due semi rossi, e due rosse di fila bastavano — 35 battaglie
su 40 con una meccanica che il giocatore non ha ancora visto. Con il vincolo la
catena segue quanto One c'è in campo: **Baro 0/40 · Fabbro (5% One) 2/40 ·
Melon Musk (25% One) 22/40**.

Il colore è un attributo che **attraversa i mazzi** (`combo_color` sul seme): le
Cuori e i Quadri sono rosse quanto il Rosso di One. Il numero invece lega solo
dentro lo stesso mazzo.

**Un Dieci di One non esiste**: lo Zero fa il suo lavoro. Colpisce come un Dieci
(`value` 10) ma per la catena è uno zero, perché il confronto è sull'**id del
valore** e non sul numero che quel valore vale. Vale anche per i sigilli: un
potenziamento non deve poter creare o spezzare una catena. Il Pesca Quattro allunga la
catena di quattro e in cambio ti **mescola un Blocco nel mazzo**: quando quello
entrerà in campo, la catena si spegne. (Va mescolato, non messo in cima — in
cima se lo ripescherebbe subito lo stesso slot che l'ha generato.)

### Gaiofanamon

Si comprano solo di livello uno (`in_pool: false` sugli altri). Dopo l'attivazione
la carta **evolve e finisce negli scarti**, e **la crescita resta per il resto
della partita**: un cucciolo comprato adesso è un veterano fra due round. È
l'unico mazzo che si potenzia da solo, ed è per questo che costa più di quello
che rende il giorno che lo compri (`price_multiplier` 1.25).

Quattro linee, tre livelli — tranne l'elettro, che si ferma a due:

| seme | I | II | III |
|---|---|---|---|
| acqua | Sgorga | Sgorga Da Bon | E' Canon |
| fuoco | Scintela | Fughett | E' dragh |
| erba | Zappin | Zappoun | Zappador |
| elettro | Sorc | Rataz | — |

Il meccanismo: `RunState.battle_deck()` marca ogni copia con `Card.origin` (il
suo posto nel mazzo), il `Duel` annota in `evoluzioni` chi è cresciuto, e a fine
battaglia `RunState.evolvi()` incassa. **Vale anche se la battaglia è persa.**
Le carte nate in campo — Germoglio, la creatura dell'Antigh, una carta rubata —
hanno `origin` -1 e non hanno un posto a cui tornare.

Dentro la singola battaglia l'evoluzione paga ancora solo se la carta torna in
gioco, e restano quindi anche l'archetipo che si accoppia al recupero — Coppe,
Fiori, l'Otto, il sigillo Eco.

**Sorc si ottiene in due modi**: in bottega come qualsiasi cucciolo, oppure
dall'incontro *Un problema shockante*, che lo regala ma ti lascia la prossima
battaglia con le carte intorpidite. Stessa carta, prezzo diverso.

Il livello dell'elettro si ferma con un `"evolves_to": ""` nella voce di
`specials.json` di `elettro_g2`: `evolves_to` sta sul **valore**, e il valore è
in comune fra i quattro semi. `elettro_g3` non è nemmeno costruibile
(`rank_ids` sul seme), o resterebbe una carta senza nome e senza disegno che
nessuno può raggiungere.

## File

| File | Cosa c'è |
|---|---|
| `game/logic/card.gd` | una carta: seme, valore, sigilli, attesa, testo. |
| `game/logic/card_library.gd` | costruisce le carte dai JSON e genera mazzi da ricetta. |
| `game/logic/card_pile.gd` | pila e scarti. **Non rimescola in blocco: è voluto.** Una carta alla volta sì (`recover`). |
| `game/logic/side.gd` | uno schieramento: vita, scudo, plancia, deck-out. |
| `game/logic/duel.gd` | **la simulazione**: tick, attivazioni, effetti, esito. |
| `game/logic/run_state.gd` | mazzo, oro, vite, round, bonus della run. |
| `game/logic/market.gd` | offerte, prezzi, acquisti, sigilli, rimozioni. |
| `game/logic/event_book.gd` | gli incontri e i loro effetti fuori battaglia. |
| `game/ui/card_view.gd` | una carta a schermo, in tre misure. |
| `game/ui/gesti.gd` | **le animazioni di battaglia**: fantasmi, numeri, lampi. |
| `game/ui/card_detail.gd` | la scheda che si apre col mouse sopra una carta. |
| `game/ui/dialogo.gd` | il fumetto: ritratto, riquadro, e il faro sul tutorial. |
| `game/data/dialoghi.json` | le scene: storia e tutorial, battuta per battuta. |
| `game/data/personaggi.json` | chi parla: nome, ritratto, da che lato sta. |
| `game/data/tutorial.json` | GiGi e le carte che regala a fine partita di prova. |
| `game/ui/carte_art.gd` | trova il disegno di una carta fra i file su disco. |
| `game/ui/side_panel.gd` | barra della vita e riquadro informazioni di uno schieramento. |
| `game/ui/round_badge.gd` | il numero del round nel cerchio, in battaglia. |
| `game/ui/main_menu.gd` | titolo, New Game, Continua, impostazioni, crediti. |
| `game/play.gd` | la schermata e il ciclo incontro/bottega/battaglia. |
| `game/data/families.json` | **i quattro mazzi**: peso in bottega, prezzo, colore. |
| `game/data/suits.json` | **i semi: qui vive il bilanciamento grosso.** |
| `game/data/ranks.json` | i valori, con il tema del numero attaccato. |
| `game/logic/budget.gd` | il metro: quanto vale una carta. Non è una regola di gioco. |
| `game/data/specials.json` | le carte con carattere, di solito le figure. |
| `game/data/seals.json` | i sigilli applicabili alle carte. |
| `game/data/events.json` | gli incontri: quattordici, e alcuni capitano solo a certe condizioni. |
| `game/data/opponents.json` | i dieci avversari, uno per vittoria: una ricetta e un archetipo l'uno. Gigi non c'è: guida il tutorial, non lo si batte. |
| `game/data/relics.json` | i diciannove artefatti. Tre si guadagnano solo agli incontri (`in_shop: false`). |
| `game/art/personaggi/` | i ritratti. Li usano gli avversari (`portrait`) e gli incontri (`image`). |
| `game/data/tuning.json` | vita, mazzo, economia, prezzi. |

## La storia e il tutorial

Una partita nuova comincia con l'introduzione al bar, poi con una **partita di
prova contro GiGi** — che non conta: nessuna vittoria, nessuna vita, non fa
avanzare gli avversari (`RunState.tutorial`). Il mazzo di partenza è **solo
briscola**; le carte di città le regala GiGi alla fine, e il regalo lo versa
`RunState.finish_round` — **non `play.gd`**, o una run simulata giocherebbe per
sempre con dodici carte che nessun giocatore ha mai in mano.

Le scene stanno in `dialoghi.json`, una voce l'una, con un campo `quando` che
dice a quale momento sono agganciate:

| `quando` | scatta |
|---|---|
| `inizio` | all'avvio di una partita nuova |
| `tutorial_inizio` | prima della partita di prova |
| `tutorial_tavolo` | a tavolo apparecchiato, col duello **fermo** |
| `dopo_tutorial` | finita la prova, col regalo di GiGi |
| `prima_bottega` · `terza_bottega` | entrando in Bottega Angelini |
| `dopo_vittoria_1` · `prima_vittoria_2` · `prima_ultima` | fra una sfida e l'altra |
| `vittoria` · `sconfitta` | prima della schermata finale |

Una battuta è `{"chi": ..., "testo": ...}`, oppure una didascalia senza `chi`,
oppure `{"capitolo": ...}`. E in più, su qualsiasi battuta:

```json
{"chi": "gigi", "testo": "Da qui vedi tutto quello che hai.", "evidenzia": "vedi_mazzo"}
```

**`evidenzia` è quello che lega il tutorial al gioco**: buca il velo attorno a
quel pezzo di schermata e ci mette una cornice d'ottone, così GiGi parla della
cosa illuminata invece che in astratto. Le chiavi le registra `play.gd` con
`_segna("nome", nodo)` — oggi: `insegna`, `vittorie`, `vite`, `oro`, `vetrina`,
`reliquie`, `innesti`, `vedi_mazzo`, `vedi_reliquie`, `rimescola`, `butta`,
`prosegui`, `vita_mia`, `vita_sua`, `fila_mia`, `fila_sua`, `pila_mia`,
`pila_sua`. Una chiave che in quella schermata non esiste non è un errore: niente
buco, velo pieno.

Il rettangolo si richiede **a ogni frame**, non una volta all'apertura: la
lezione della bottega si apre nello stesso frame in cui la bottega nasce, e lì
dentro i contenitori non hanno ancora posizionato niente.

Chi pilota la scena da `tools/` alza `play.senza_dialoghi = true` **prima** di
`add_child`: salta i dialoghi *e* la partita di prova, ma versa lo stesso il
regalo, così misura il mazzo vero.

## Modifiche tipiche

**Cambiare come si comporta un seme** → `suits.json`. L'effetto legge il valore
della carta con `{"stat": "value", "of": "card", "scale": k}`, e l'attesa è
`base + valore × per_value`:

```json
{"id": "picche", "name": "Picche", "symbol": "♠", "family": "city",
 "color": "danger", "cooldown": {"base": 2.0, "per_value": 0.30},
 "effects": [{"type": "damage", "amount": {"stat": "value", "of": "card", "scale": 1.0}}]}
```

**Dare carattere a una carta** → una voce in `specials.json` con l'id
`<seme>_<valore>`. Gli effetti si aggiungono a quelli del seme, salvo
`"replace": true`:

```json
{"id": "picche_c13", "name": "Re di Picche",
 "text": "Colpisce e brucia la carta avversaria più vicina.",
 "effects": [{"type": "burn", "amount": 1}]}
```

**Nuovo sigillo** → `seals.json`: `value_mult`, `cooldown_mult`, `cooldown_add`,
`extra_effects`. Due per carta, non di più.

**Nuovo avversario** → `opponents.json`, una ricetta invece di un mazzo scritto.
I `weights` sono l'archetipo: quanto pesca da ciascun mazzo, in percentuale.

```json
{"id": "contadino", "name": "Il Vecchio Contadino",
 "portrait": "res://game/art/personaggi/contadino.png",
 "hp": 55, "shield": 0, "deck_size": 22, "value_range": [3, 8],
 "weights": {"poker": 10, "briscola": 65, "one": 5, "gaiofanamon": 20},
 "rules": [{"family": "briscola", "value_add": 2}]}
```

Due leve che fanno la differenza fra un avversario e un archetipo:
`rules` — bonus validi per tutto il suo mazzo, con lo stesso vocabolario dei
passivi del giocatore (è così che il Contadino gioca carte piccole che valgono
più di quello che c'è scritto sopra) — e `seals` + `seal_every` +
`seals_per_card`, che è tutto il Fabbro: non ha carte più forti, ha le stesse
carte temperate meglio.

Il manuale che li mette a confronto è `docs/avversari.md`, generato.

**Effetti degli incontri**: `run_gold`, `run_max_hp`, `run_life`, `run_add_card`,
`run_remove_card`, `run_seal`, `run_passive`, `run_relic` (una precisa o una a
caso), `run_end` (chiude la partita), `run_next_battle` (uno strascico che vale
solo per la battaglia dopo e poi si consuma), `run_swap_suit` (lo scambio del
Gaiofanamon). Un incontro può avere un `requires`: `{"family": "gaiofanamon"}`
capita solo a chi ne ha uno, con `"none": true` solo a chi non ne ha.

Le chiavi di una reliquia: `max_hp_add` · `lives_add` · `cards_add` (con
`cards_family` e `cards_range` per i Deckbox) · `board_add` · `gold_per_round_add`
· `start_shield` · `price_mult` · `status_resist` (quanto veleno e sanguinamento
ti scrolli di dosso) · `start_combo` (con quanta catena cominci) · `rule`.

Una reliquia con `rounds` **scade**, e portandosi via la regola che aveva
installato; una con `"in_shop": false` si guadagna solo agli incontri.

**Effetti disponibili**: `damage`, `heal`, `shield`, `gold`, `burn`, `slow`,
`haste`, `recycle`, `bleed`, `poison`, `cleanse`, `paralyze`, `slot_buff`,
`match_buff`, `value_debuff`, `mill`, `recover`, `steal`, `spawn_card`, `combo`,
`combo_reset`. Fuori battaglia (eventi): `run_gold`, `run_max_hp`, `run_life`,
`run_add_card`, `run_remove_card`, `run_seal`, `run_passive`.
Nuovi → `_register_effects()` in `duel.gd` o `event_book.gd`, **più** una voce in
`Card.EFFECT_LABELS` e un peso in `CardBudget.PESI_UTILITY`.

Tre aggettivi che si mettono su un effetto invece di essere effetti a sé — così
compongono con `chance`, `repeat` e i sigilli:

| | |
|---|---|
| `"pierce": true` | il colpo passa attraverso lo scudo (Spade) |
| `"target": "self"` | lo rivolge contro chi lo lancia (Picche) |
| `"when": "tick"` / `"enter"` | ogni secondo in plancia / appena entra, invece che all'attivazione |

## Il metro del bilanciamento

Centocinquanta carte non si tarano a occhio. `game/logic/budget.gd` traduce
tutto in **punti** (un punto = un danno) e in **punti al secondo**, che è l'unica
grandezza confrontabile fra una carta veloce e piccola e una lenta e grossa.

```bash
# quali carte sono fuori riga, dalla più forte alla più debole
godot --headless --path templates/cittacampagna --script res://tools/diagnosi_carte.gd
```

`tests/budget_test.gd` sorveglia cinque cose: a parità di valore i semi si
equivalgono · dentro un seme la curva sale · le figure sono un premio non un
altro gioco · le famiglie rendono uguale (confrontate **sui valori in comune**,
non sulla media) · nessuna carta sfonda il tetto.

L'ordine per ritoccare i numeri, dal ciclo più corto al più lungo:
`diagnosi_carte` → `test.sh cittacampagna budget` → `duel` → `tuning.json`
(HP e mazzi, **insieme**) → `economy` → `balance` → `diagnosi_economia`.

> **I cooldown non riportano in gioco il deck-out.** Allungarli rallenta insieme
> il danno *e* il consumo del mazzo: il rapporto non si muove. Servono al ritmo
> e alla leggibilità, mai all'equilibrio fra le due sconfitte.

**Bilanciamento** → `tuning.json`, poi **F5** in gioco. Poi `./tools/test.sh
cittacampagna balance`.

## Provare la partita, non solo la logica

`./tools/test.sh cittacampagna` copre le regole, non la schermata. I bug della
scena — nodi liberati, pannelli che non compaiono, transizioni che non scattano —
si vedono solo giocando. Per quello ci sono tre strumenti in `tools/`:

```bash
# gioca una partita intera da solo: combatte, sceglie agli incontri, va avanti.
# Esce con 1 se resta fermo nella stessa schermata. Args: <round> [seed]
godot --headless --path templates/cittacampagna \
      --script res://tools/regressione_partita.gd -- 8 4242

# porta la run a un round e forza un finale preciso, poi racconta cosa succede.
# Args: <round|last> <deckout|deckout_mio|pareggio|hp|hp_mio>
godot --headless --path templates/cittacampagna \
      --script res://tools/repro_finale.gd -- last deckout

# come sopra ma fotografa la schermata che resta dopo la fine.
godot --path templates/cittacampagna \
      --script res://tools/repro_visivo.gd -- 3 deckout /tmp/finale.png 240

# compra in bottega per sette accessi di fila e controlla che le righe non si
# gonfino, che le vetrine cambino e che niente di già comprato torni in vendita.
godot --headless --path templates/cittacampagna \
      --script res://tools/repro_bottega.gd -- 4242

# gioca, esce, rientra da "Continua" e verifica che la partita riprenda dov'era.
godot --headless --path templates/cittacampagna \
      --script res://tools/repro_continua.gd -- 3

# la schermata di battaglia sta ferma, o balla? Esce con 1 se qualcosa cambia
# larghezza mentre il duello va avanti. Args: <round> [seed]
godot --headless --path templates/cittacampagna \
      --script res://tools/misura_stabilita.gd -- 10 4242

# quanto è fluida davvero. NON usare --fixed-fps: qui serve il tempo vero.
# Args: [round] [seed] [secondi]
godot --path templates/cittacampagna \
      --script res://tools/misura_fluidita.gd -- 9 4242 10

# registra una battaglia INTERA, dalla prima carta al verdetto, e annota quando
# suona cosa. Args: <cartella> [round] [seed] [velocità] [passo]
godot --path templates/cittacampagna --fixed-fps 60 \
      --script res://tools/registra_battaglia.gd -- /tmp/battaglia 9 4242 1 1
ffmpeg -framerate 60 -i /tmp/battaglia/f%04d.png \
       -c:v libx264 -pix_fmt yuv420p -crf 20 battaglia.mp4

# fotografa bottega, mazzo, battaglia e incontro, per confrontarli con le bozze.
godot --path templates/cittacampagna \
      --script res://tools/foto_schermate.gd -- /tmp 4242

# le quattro linee dei gaiofanamon in fila, coi disegni e la scheda aperta.
# Che CarteArt trovi *un* file lo dice un test; che sia la creatura giusta no.
godot --path templates/cittacampagna \
      --script res://tools/foto_gaiofanamon.gd -- /tmp

# registra una sequenza come clip animata, per una presentazione o per itch.io:
# battaglia · bottega · carte · incontro · dialogo. Va lanciato in primo piano.
godot --path templates/cittacampagna --fixed-fps 60 \
      --script res://tools/foto_clip.gd -- bottega /tmp/clip 4242 180
img2webp -loop 0 -d 50 -q 70 -m 6 /tmp/clip/f*.png -o bottega.webp

# racconta l'economia round per round: prezzi medi e storia di dodici run.
# Da eseguire quando balance_test diventa rosso: dice *dove* si rompe.
godot --headless --path templates/cittacampagna \
      --script res://tools/diagnosi_economia.gd
```

> **Il tempo di una clip se lo governa lo strumento, non l'orologio.** Salvare un
> PNG costa due decimi di secondo e Godot non aspetta: continua a simulare e
> salta i disegni. Da qui le due regole di `foto_clip.gd` — `--fixed-fps 60`, che
> fissa il `delta` a 1/60 qualunque cosa succeda, e il disegno **chiesto** con
> `RenderingServer.force_draw()` una iterazione su tre. Senza, la clip mostra il
> gioco venti volte più veloce di com'è. `foto_gesti.gd` non ha il problema
> perché serve a guardare i gesti al rallentatore, non a registrarli.

**Esegui `repro_bottega.gd` dopo ogni modifica a `_refresh_shop()`.** Ogni riga
che quella funzione ridisegna va prima svuotata con `_clear()`: dimenticarne una
non dà nessun errore, i vecchi nodi restano e la riga cresce a ogni acquisto.

### La regola dei nodi, pagata cara due volte

> **Ciò che viene ridisegnato deve nascere dentro la funzione che lo ridisegna.**

Un nodo tenuto in una variabile membro e infilato in un contenitore che poi passa
sotto `_clear()` viene liberato insieme a lui. Al giro dopo `add_child` fallisce
con *"already has a parent"*, e ogni riga che tocca quel nodo diventa un errore
che **interrompe la funzione a metà**. Se capita dentro un handler di segnale —
`_on_ended`, per dire — la partita si ferma e non riparte più.

In `play.gd` restano variabili membro **solo** i contenitori che nessuno svuota
mai (`_shop_panel`, `_battle_panel`, `_event_panel`, `_overlay_panel`). L'unica
eccezione che c'era — la riga di resoconto della battaglia — non c'è più, e la
regola adesso non ha eccezioni.

Corollario, per gli handler di segnale: **prima si fa avanzare lo stato, poi si
tocca la UI.** Così un nodo morto rovina la grafica di un frame, non la partita.

### Il salvataggio

`RunState.save()` scrive `user://save.json` (chiave `"run"`); il menu alza
`options.resume` e `play.gd` la legge per decidere se riprendere o ricominciare.
Si salva **subito dopo `finish_round`**, non all'ingresso in bottega: fra i due
c'è un secondo e mezzo di animazione, e chi chiude la finestra lì in mezzo
perderebbe il round appena vinto.

Si salvano **solo gli id** — seme, valore, innesti, reliquie — mai gli effetti
già calcolati: altrimenti un salvataggio si porta dietro il bilanciamento di
ieri anche dopo aver toccato `suits.json`.

Il ripristino **non ripassa da `add_relic()`**: le reliquie una tantum (vita
massima, vite, carte) hanno già versato il loro effetto quando sono state
comprate, e riapplicarle regalerebbe vita e carte a ogni caricamento.

E se scrivi test che toccano il salvataggio: **metti da parte `user://save.json`
e rimettilo a posto**, altrimenti eseguire la suite cancella la partita di chi
sta giocando.

**Esegui `regressione_partita.gd` dopo ogni modifica a `play.gd`.** Il softlock
di fine partita è vissuto due round senza che nessun test lo vedesse, perché
nasceva solo alla *seconda* costruzione della schermata di battaglia.

## Le animazioni della battaglia

Il problema che risolvono è uno solo, e non è estetico: in `duel.gd::_activate`
la carta spara, viene scartata e rimpiazzata **dentro lo stesso frame**. Senza
animazioni il giocatore la carta che spara non la vede mai — vede due barre che
scendono e le facce che cambiano da sole.

`game/ui/gesti.gd` (`Gesti`) è il regista: possiede tutti i nodi effimeri, sta
**fuori da `_battle_panel`** (così nessun `_clear()` glieli porta via) e avanza
in `play.gd::_process`, accanto a `duel.advance()` — quando GiGi parla il tavolo
si ferma, e si fermano anche i gesti.

| Evento | Segnale | Cosa si vede |
|---|---|---|
| la carta spara | `Duel.card_activated` | lampo crema di 2 frame, il **fantasma** si stacca verso il bersaglio e svanisce; la cornice della carta si accende del colore dell'effetto |
| il rimpiazzo | `Side.slot_filled` | la carta nuova sale al suo posto dalla parte del proprio mazzo |
| quanto è costato | `Side.hp_changed` / `shield_changed` | un numero grosso sulla carta che ha sparato: `−4` rosso, `+5` verde, `+3` azzurro, oro per l'oro |
| bruciata / rubata / evoluta | `Duel.card_left` con `motivo` | tre versioni dello stesso gesto rovesciato: cade, scivola dal ladro, sale in gloria |

**La catena di One non è ancora animata.** Scatta 6-10 volte a battaglia con un
mazzo che ci punta — misurato, quindi abbastanza rara da meritare un gesto.
Il piano era in due tempi, **prima il contatore nell'HUD, poi la sua
animazione**, e il primo è fatto: il gettone in `side_panel.gd` si accende
insieme a veleno, sanguinamento, carte ferme e bonus di partita, e un numero a
zero non si scrive. Resta il gesto, e resta il vincolo che lo rendeva difficile:
l'unica altra cosa accendibile sono le carte del lato, che in quel momento
stanno già dicendo un'altra cosa con il colore del loro effetto — ricolorarle
d'ottone cancellerebbe quella. Il gesto, quando si farà, parte **dal gettone**.

**Il numero è la conseguenza vera, non quello scritto sulla carta.** Passando da
`hp_changed` arriva già scontato lo scudo, la catena e le resistenze, e veleno e
sanguinamento — che una carta non ce l'hanno — vengono contati gratis. Chi ha
sparato lo dice `_autore`, che si chiude su `card_left`: azzerarlo a inizio
frame invece produceva **cinque attribuzioni false in una battaglia**, perché a
4× il veleno del tick dopo cade nello stesso frame di un'attivazione già
avvenuta e ne eredita l'autore.

**Guardarle**, perché un test headless non vede un pixel:

```bash
# fotografa una battaglia vera fotogramma per fotogramma, dalla prima carta che spara
godot --path templates/cittacampagna --script res://tools/foto_gesti.gd -- 3 96 /tmp/gesti 4242 1
ffmpeg -framerate 60 -i /tmp/gesti/f%03d.png -vf fps=30 /tmp/gesti.gif
```

### Il testo che cambia decide quanto è largo lo schermo

> **Una Label senza vincoli è larga quanto il suo testo, e quel testo cambia.**

In mezzo al tavolo c'era una cronaca della battaglia — `Tu — Cinque di Spade:
7 danni · 1 sanguinamento`, una riga a **ogni attivazione**, quaranta a
battaglia. Senza vincoli la sua larghezza minima era quella del testo intero, e
dalla colonna centrale di un HBox centrato allargava tutto il tavolo e lo faceva
tornare indietro un secondo dopo. Misurato: da 132 px («Tu — Due di Coppe:
2 cura») a **1169 px** («Il Vecchio Contadino — Re di Bastoni: 4 rallenta ·
2 indebolisce · 5 danni · …»), e al round 10 il pannello passava da 1128 a
**1513 px**, 361 dei quali fuori dallo schermo. Peggiorava andando avanti,
perché gli ultimi avversari hanno nomi lunghi e i Re cinque effetti.

**La cronaca non c'è più**, e non per il difetto — quello si sarebbe corretto —
ma perché non diceva niente che il tavolo non dicesse meglio: la carta che spara
si vede sparare, il numero del colpo esce sulla carta già scontato di scudo,
catena e resistenze, e il verdetto lo dà il riepilogo un secondo dopo con la
stessa identica frase. Al suo posto resta `_mezzeria()`, una striscia vuota che
separa il suo lato dal tuo.

Ma la trappola resta, e vale per la prossima Label che qualcuno metterà lì. La
cura è di due pezzi e servono entrambi: **`clip_text`** toglie il testo dal
calcolo della misura minima, **`SIZE_EXPAND_FILL`** le fa prendere la larghezza
che la colonna ha già. Solo il primo e la Label collassa; solo il secondo e
continua a spingere.

Lo stesso difetto, più piccolo e più subdolo, c'era nel riquadro laterale:
«9 carte in mazzo» è un carattere più corto di «13 carte in mazzo», e il
pannello si stringeva di dieci pixel **a ogni carta pescata**. Lì la cura è un
**minimo** (`LARGHEZZA_TESTO`) che tiene ferma la larghezza, più l'andare a capo
come rete di sicurezza per una lingua più lunga dell'italiano.

**Chi aggiunge in battaglia una Label il cui testo cambia deve dichiararne la
larghezza.** Non è una raccomandazione di stile: è la differenza fra una
schermata ferma e una che balla. `tools/misura_stabilita.gd` lo verifica in
dieci secondi, e va eseguito dopo ogni modifica a `_build_battle_view`.

### Fluido non vuol dire tanti fotogrammi

> **La domanda giusta non è quanti fotogrammi disegni, è quante volte al secondo
> cambia quello che disegni.**

Segnalato giocando: «va estremamente a scatti». La prima misura diceva che
andava benissimo — **120 fotogrammi al secondo, zero saltati**, il peggiore da
22 ms — e la prima misura era la domanda sbagliata.

La simulazione avanza a passi esatti di `battle.tick`, cinque centesimi: **venti
al secondo**. È quello che la rende deterministica — stesso seme, stessa
partita, carta per carta — e non si tocca. Ma le barre dell'attesa leggevano
`card.cooldown`, che cambia solo a un tick: sei disegni identici, poi uno
scatto. Misurato con `tools/misura_fluidita.gd`, che conta i **cambiamenti** e
non i fotogrammi.

La cura sta tutta dalla parte della vista. `SimClock` sapeva già quanto tempo è
passato dall'ultimo passo — se lo tiene in `_accumulator` per non perdere
frazioni — e adesso lo espone con `resto()`. `CardView.refresh()` prende un
`anticipo` e disegna **dove sarà** la barra invece di dove era:

```gdscript
var atteso := maxf(card.cooldown - anticipo, 0.0)
```

Una sottrazione. Le barre disegnate passano da **20 a 85 movimenti al secondo**,
la logica resta a venti passi esatti e i test a seme fisso non se ne accorgono.

**Se aggiungi qualcosa che si muove di continuo in battaglia, interpolalo allo
stesso modo.** Leggere il valore dell'ultimo tick è comodo e sbagliato: la
simulazione va a venti, lo schermo a centoventi.

### Le trappole delle animazioni, tutte misurate

- **Un `Container` riscrive `position` e azzera `scale` dei figli**, e a
  riordinare basta una carta vicina che cambia testo — o **F5**, che riassegna
  il tema e fa `queue_sort()` su tutto l'albero. Per questo ogni carta in
  battaglia sta dentro una **cella** (`play.gd::_cella`), un `Control` nudo che
  non tocca niente. Dentro la cella la posizione è nostra.
- **Il bordo di `_style` non si vede sulle carte illustrate.** `_art` è un
  figlio del PanelContainer e con i margini a zero lo copre. Il bordo sta su
  `_cornice`, un `Panel` con `draw_center = false` aggiunto per ultimo. Da qui
  la divisione: **`_style` è il fondo, `_cornice` è il bordo.**
- **`modulate` moltiplica, non schiarisce.** Un lampo bianco con
  `modulate = Color(3,3,3)` su un'illustrazione vera rende bianco pieno il
  30-60% dei texel e lascia neri i contorni: si vede una carta sovraesposta, non
  una sagoma. Il lampo è un `ColorRect` sopra il fantasma. Stessa storia sulle
  barre: `_timer` e `_hp_bar` nascono con un colore nello StyleBox "fill", e
  tingerle con `modulate` dà un verde oliva — si muta `bg_color` del
  riempimento.
- **Niente `scale`, mai.** L'illustrazione è 240×330 dentro 120×165, esattamente
  metà: qualunque altro fattore con filtro `NEAREST` raddoppia righe di pixel a
  caso, e in movimento è tremolio.
- **Ogni nodo effimero deve essere cieco al mouse**, radice compresa. I default
  non aiutano (`ColorRect` e `PanelContainer` sono STOP, `TextureRect` è PASS):
  uno solo sopra una carta e la scheda del dettaglio comincia a sfarfallare,
  senza lasciare un errore in console. Ci pensa `Gesti._adotta()`.
- **Gli agganci si fanno dopo `_build_battle_view()`.** Prima di quella riga
  `_views` e `_panels` contengono le viste della battaglia scorsa: non sono nodi
  liberati — il pannello viene nascosto, non svuotato — quindi
  `is_instance_valid` non se ne accorge e un gesto parte su coordinate
  plausibili e sbagliate.
- **A fine battaglia serve un taglio netto.** `_process` esce su `duel.is_over`
  e non fa più girare niente: `_gesti.svuota()` e `CardView.concludi()` su ogni
  vista, **dopo** `_aggiorna_schermata_finale` (che ripassa da `_refresh_slot` e
  rimetterebbe in moto gli ingressi).
- **Il tempo si conta in sessantesimi**, non in frame di schermo: su un monitor a
  144 Hz una tabella di pose letta a ogni frame durerebbe due volte e mezzo di
  meno. Da qui l'accumulatore in `Gesti.passo()`.
- **Niente Tween.** Un contatore che avanza dentro `_process` si ferma insieme
  alla simulazione e muore con il nodo che anima; un Tween continua a correre
  sotto il velo di un dialogo e sopravvive al suo bersaglio.
- Il carico vero, contato sui segnali: **1,1 attivazioni al secondo a 1×,
  4,4-4,9 a 4×** — non le tre e le dodici che si stimano a mente, perché la
  briscola porta la media dei cooldown vicino ai nove secondi. Per questo non
  c'è nessun budget: sarebbe codice che non gira mai.

## Asset: cosa entra dove

I disegni delle carte ci sono (`game/art/carte/`); i suoni sono ancora
sintetizzati a runtime. Gli asset si aggiungono così.

**I suoni ci sono tutti e sedici**, in `game/audio/`, più tre valzer. Non è più
il sintetizzatore del core a suonare: quello resta la rete di sicurezza, e
`tests/audio_test.gd` fallisce se un suono ci ricasca di nascosto — è la stessa
regola dei disegni, dove `SENZA_DISEGNO` deve restare vuota.

**La tesi, se tocchi qualcosa non contraddirla**: tutto il gioco suona con due
materiali soli, l'**ancia della fisarmonica** e il **legno del bancone**. Il
metallo è per l'oro, la carta per i movimenti. Niente onde quadre: la partita si
gioca in un bar di Gaiofana, e lì un bip da console non l'ha mai sentito nessuno.
La musica è **liscio** — valzer in 3/4, basso sull'uno, accordo sul due e sul
tre — perché è la musica che in quel bar ci sarebbe davvero.

Li genera uno strumento, non un DAW:

```bash
python3 tools/genera_audio.py                # riscrive tutto game/audio/
python3 tools/genera_audio.py --solo click   # itera su un suono solo
python3 tools/genera_audio.py --referto      # solo le misure, non scrive niente
```

Ogni suono è una funzione di venti righe con dei numeri dentro: «il click è
troppo sibilante» è un parametro, non un ticket. Il seme è fisso, quindi
rigenerare due volte dà file identici byte per byte e un diff dice se è
cambiato qualcosa davvero. Il referto misura le cinque cose che si controllano
senza orecchie — durata, picco, componente continua, centroide, saturazione:
non dicono se un suono è bello, dicono se è rotto.

**Sostituire un file generato con una registrazione vera non richiede codice.**
`core/autoload/audio.gd` cerca prima il file e sintetizza solo se non lo trova,
e vale sia per gli effetti sia per la musica: `Audio.music("musica_battaglia")`
si risolve per **nome** esattamente come `Audio.sfx("hit")`. Togliere il file fa
tornare il sintetico. Con **F5** la cache si svuota, quindi il file nuovo si
sente senza riavviare.

Formato: **`.ogg`** per la musica (l'unico che Godot fa ciclare bene), `.wav`
per gli effetti corti. Niente `.mp3` per la musica in loop: lascia un buco.

> **Un loop non si chiude ripiegando la coda sull'inizio.** Quel gesto *sposta*
> la risonanza dell'ultimo accordo invece di lasciarla dov'è, e il file finisce
> in un silenzio che agli altri confini di battuta non c'è — misurato, non
> temuto: su `battaglia` la giuntura scendeva a 0,056 contro un minimo di 0,083
> negli altri confini. Il pezzo si suona **tre volte di fila e si ritaglia
> quella di mezzo**: il loop non si chiude perché non si è mai aperto.

Quali suoni suonano e dove, oggi: ogni bottone fa `click` e `hover` da solo
(`core/autoload/ui.gd`), la battaglia ha `hit`/`hurt` a ogni attivazione più
`explosion` sulla bruciatura, la bottega ha `buy`, `error`, `level_up`,
`cancel`, `whoosh` sul rimescolo, e `win`/`lose` suona **una volta sola**, a
fine run, dal Router — a fine battaglia c'è un gesto corto (`confirm`/`cancel`),
o si sentiva lo stesso valzer due volte a un secondo di distanza.

**Il resto della battaglia è ancora muto** e non è una svista: danno che arriva,
cura, scudo, evoluzione, riciclo, catena, veleno, paralisi, deck-out imminente.
Sono una quarantina di momenti mappati uno per uno nel backlog. Vanno aggiunti
**accorpando per frame** (una richiesta per nome, la più forte) e non uno per
segnale: misurate 1,26 attivazioni al secondo a 1× e 5,05 a 4×, e dando un suono
a danno, cura, scudo e ingresso si arriverebbe a ~18/s a 4× — le dodici voci
ciclate in 0,66 s contro effetti che durano fino a 0,6 s.

**I disegni delle carte — un file, nessuna riga di codice**, se sta nel posto
giusto col nome giusto. `game/ui/carte_art.gd` li cerca in
`game/art/carte/<famiglia>/`, e **la cartella si chiama esattamente come la
famiglia in `families.json`**: rinominare una famiglia e lasciare indietro la
cartella toglie il disegno a tutte le sue carte *in silenzio* — nessun errore,
solo carte scritte invece che illustrate. `tests/data_test.gd` adesso se ne
accorge.

Dentro la cartella ogni mazzo ha la sua convenzione, e stanno tutte in
`CarteArt._candidati`:

| famiglia | nome del file | esempi |
|---|---|---|
| briscola | `card_<seme>_<valore>.png` | `card_denari_re.png` |
| poker | `card_<valore>_<seme>.png` | `card_K_S.png` |
| one | `card_<colore-inglese>_<n>.png` | `card_red_5.png`, `card_blue_plus2.png` |
| gaiofanamon | **mappa esplicita** `CarteArt.SPRITE_PER_CARTA` | `acqua_g3` → `Canon.png` |

I gaiofanamon non hanno una regola: i file portano il nome che il disegnatore ha
dato alla creatura, e su apostrofi e abbreviazioni quel nome non coincide con
quello dei dati — `E' Canon` sta su disco come `Canon.png`, `L'antigh` come
`Antig.png`. Una mappa esplicita dice la verità; una regola che ci prova indovina
undici volte su dodici e lascia una carta bianca senza dirlo. Dopo la mappa si
prova comunque il nome così com'è e senza spazi, per le carte che arriveranno.

**Ogni carta del gioco ha il suo disegno**, e `data_test.SENZA_DISEGNO` è vuota:
tenerla vuota è la regola. Due carte ci arrivano per strade storte, e vale la
pena saperlo prima di cercarle:

| carta | file | perché |
|---|---|---|
| Jolly | `poker/joker_colored.png` | la regola del poker compone valore e seme, e lui un seme non ce l'ha: sta nella mappa |
| Blocco | `one/blocco_b0.png` | lo `skip` in grigio. **Non ha colore**: vestirlo di rosso lo farebbe sembrare una carta che allunga la catena proprio mentre la spegne |

Prima di tutte si prova sempre `<famiglia>/<id_carta>.png` (`germoglio_s1.png`):
è la via per dare un disegno suo a una carta sola.

**Misura: 240×330 px**, `.png`. Sono il doppio esatto di `CardView.SIZES` —
frazioni diverse fanno scalare il disegno a metà pixel e il pixel art sfarina.

**Le illustrazioni degli incontri** stanno in `game/art/eventi/`, **1024×576**
(16:9, il doppio di come si vedono). Si agganciano con un campo `"image"` in
`events.json`, e non solo sull'incontro: **anche su una singola scelta**, e allora
quel disegno prende il posto dell'altro nella schermata dell'esito — serve alle
scelte che cambiano la scena, come la partita che finisce o l'avversario che
rovescia il tavolo. Senza `"image"` resta il `"symbol"`, che tiene il posto senza
far saltare il layout.

Le altre immagini: ritratto di un avversario 256×256, sfondo 1152×648 o multipli
(`.png` / `.webp`).

**Font**: `.ttf` o `.otf` in `game/fonts/`, poi vanno agganciati in
`core/ui/theme_builder.gd`.

Dopo aver copiato i file: `godot --headless --path templates/cittacampagna
--import` genera i `.import`, altrimenti Godot non li vede.

## La traduzione, che non c'è ancora

Il gioco è in italiano e ci resta finché qualcuno non traduce. Quello che è
stato fatto non è una traduzione: è **la possibilità di farne una senza
riscrivere il gioco**. Se scrivi testo nuovo, queste sono le regole.

**La chiave è la frase italiana.** Godot traduce da solo il testo che finisce
in `Label.text` o `Button.text`, cercando la stringa italiana nel catalogo e
restituendola invariata se non la trova. Tre conseguenze, tutte volute: si
traduce **a fette**, senza rompere niente; l'italiano non ha bisogno di essere
tradotto; e **i JSON di `game/data/` restano in italiano per sempre**.

> **Tradurre i JSON sul posto rompe il gioco in silenzio.** `carte_art.gd`
> costruisce il nome del file del disegno dal nome della carta, e `game_over.gd`
> ritrova il record da una chiave che è anche un'etichetta. Il catalogo è
> l'unico posto dove può stare un'altra lingua.

```bash
python3 tools/estrai_testi.py            # ricostruisce game/i18n/testi.csv
python3 tools/estrai_testi.py --referto  # dice cosa è cambiato, non scrive
python3 tools/estrai_testi.py --lingua en   # aggiunge una colonna
godot --headless --path . --import       # genera i .translation
```

Il catalogo oggi ha **996 chiavi**: 642 dai JSON, 237 dai `.gd`, 153 nomi di
carte che non esistono in nessun file — «Asso di Picche» nasce unendo valore e
seme a runtime. Il nome composto sta in catalogo **intero**, ed è anche l'unico
modo di avere un tedesco decente: «Pik-Ass» non si ottiene riordinando
segnaposti. Due terzi delle parole stanno in `dialoghi.json`.

**Le due forme che Godot non salva**, e sono l'unica cosa da ricordare:

| | |
|---|---|
| il formato applicato **prima** | `Ui.label("Round %d" % n)` non si traduce mai: la chiave cercata è la frase col numero dentro. Si scrive `Ui.label(tr("Round %d") % n)`. Il `%` **dopo** `tr()`, mai dentro. |
| la desinenza cucita nel formato | `"%d cart%s" % [n, "a" if n == 1 else "e"]` non è traducibile *affatto*: quel `%s` porta mezza parola italiana. Si scrive `Testo.plurale(n, "%d carta in mazzo", "%d carte in mazzo") % n`. |

`tr()` è un metodo di `Object`: in una funzione **static** non si raggiunge, e
lì si usa `Testo.traduci()`. `Testo` sta in `core/ui/testo.gd` e dichiara il
proprio limite: due forme di plurale, che bastano a EN, ES, FR, DE, PT. Le
lingue slave ne vogliono tre e chiedono i plurali veri del formato `.po`; quel
giorno cambia quella funzione, non i suoi punti d'uso.

**Il layout si controlla senza avere una traduzione.** `F7` accende la *lingua
finta*: le stringhe si allungano del 30% e si riempiono di accenti, come farebbe
un tedesco. L'italiano è fra le lingue più corte che ci interessano, quindi un
layout che regge l'italiano non dimostra niente.

```bash
godot --path . --script res://tools/misura_larghezze.gd   # dice quale riga sfora e di quanto
```

Con la lingua finta accesa, misurato: **la battaglia sforava di 36 px** — il
riquadro laterale, sistemato: le sue righe adesso vanno a capo dentro
`LARGHEZZA_INFO`, che era un minimo e ora è anche un tetto. Il mazzo aperto e
gli incontri stanno dentro. Se aggiungi una Label dentro una colonna di
larghezza fissa, dalle `autowrap_mode` e un `custom_minimum_size.x`, o la
prossima lingua la fa uscire dallo schermo.

**La bottega no, e non è un difetto da correggere con un numero.** La sua riga
in alto — «Vittorie x/y · N vite · Vedi mazzo (N) · Vedi reliquie (N) · N oro» —
occupa 1128 px su 1152: ha il **2% di margine**. Con la lingua finta sfora di
310 px, e due terzi sono i due bottoni «Vedi …». Fissarne la larghezza non
serve: in italiano «Vedi reliquie (12)» è già più largo di qualunque tetto
sensato e verrebbe troncato prima ancora di tradurre. È una scelta di
contenuto — etichette più corte, o un'icona col numero accanto — e va presa
insieme alla prima lingua vera, non prima.

> **`clip_text` su un Button non è mai la risposta ovvia.** In Godot azzera la
> larghezza minima: un bottone senza `custom_minimum_size` e non stirato da un
> genitore **collassa a 8 px**. Messo dentro `Ui.button` per tutti, ha fatto
> sparire «Vedi mazzo», «Vedi reliquie», «Chiudi» e l'«Avanti» degli incontri —
> cioè il modo di uscire da un incontro — senza un errore in console. Ora si
> chiede con `Ui.button(testo, azione, larghezza)`: la larghezza minima e il
> taglio arrivano insieme, e non possono separarsi.

**Il font non è un problema**: Departure Mono copre 191 dei 192 codepoint di
Latin-1 e Latin Extended-A — ES, FR, DE, PT e PL passano senza toccare niente.
Manca solo `ŉ`, che non serve a nessuna lingua viva. Ma i font sono importati
con `allow_system_fallback=false`, quindi **ogni lingua nuova va verificata
sulla cmap prima**, non a schermo dopo: un glifo mancante non ripiega, disegna
un quadratino. Ed è monospaziato, il che rende esatta la stima d'ingombro di una
traduzione: basta contare i caratteri (0,636 em l'uno, cioè 10,18 px a `TESTO`).

`tests/i18n_test.gd` sorveglia tutto questo: nessuna desinenza cucita, nessun
`%` dentro `tr()`, ogni carta nel catalogo, e — il più importante — **con la
lingua finta accesa ogni carta trova ancora il suo disegno**.

## L'audio sul web, che è tutta un'altra cosa

Due difetti diversi hanno reso la build web completamente muta, e nessuno dei
due si vede da desktop né da un test.

- **`audio/general/default_playback_type.web=0` in `project.godot` non è
  opzionale.** Dal 4.4 Godot sul web usa di default il playback **Sample**
  (=1), che consegna i suoni direttamente a WebAudio saltando il mixer del
  motore. Qui quel percorso **non produce niente**, e non lo dice: nessun
  errore in console, `AudioStreamPlayer.playing` vero, la posizione che avanza.
  Con `0` (Stream) mixa il motore e si sente.
- **La trappola dentro la trappola**: con Sample il picco dei bus
  (`AudioServer.get_bus_peak_volume_left_db`) resta a **−200 dB anche quando
  tutto funziona**, perché dai bus non passa niente. È l'indicatore che verrebbe
  naturale usare per diagnosticare, ed è cieco proprio nella configurazione da
  diagnosticare.
- **Il primo gesto va intercettato in `_input`, mai in `_unhandled_input`.** Il
  browser tiene sospeso l'audio finché l'utente non tocca qualcosa, quindi la
  musica del menu aspetta il primo evento — ma `_unhandled_input` vede solo ciò
  che nessun Control ha consumato, e il menu è tutto bottoni sopra uno sfondo
  che ferma il mouse. Col mouse non arrivava niente, con la tastiera sì: per
  questo in prova sembrava a posto.
- **Niente di tutto questo è verificabile in un browser headless.** Chromium
  senza dispositivo audio non renderizza il grafo: un AnalyserNode legge zero
  anche su un oscillatore vero, e il mixer di Godot — che è pilotato dal
  callback audio del browser — non gira mai. L'unica strada è una sonda che
  scrive lo stato **sullo schermo** e una persona con le casse che la legge.

## Da sapere

- **Il veleno morde ogni tre secondi, non ogni secondo** (`battle.poison_every`).
  Non è ritmo, è prezzo: un danno *al secondo* che non finisce mai vale, in una
  battaglia normale, quasi dieci danni — più di quanto qualunque carta possa
  permettersi a qualsiasi cooldown. Diradandolo resta quello che è (fisso, non
  se ne va finché non lo lavi) a un prezzo pagabile.
- **Veleno e sanguinamento hanno un tetto** (`poison_cap`, `bleed_cap`). Il
  sanguinamento cala di uno al secondo, ma cinque carte che ne mettono uno ogni
  due secondi lo fanno salire più in fretta di quanto scenda: senza soffitto un
  mazzo di soli Due non perde mai.
- **Nessuno dei due passa dallo scudo.** Lo scudo para i colpi; contro i danni
  nel tempo la risposta è `cleanse` (Acqua). È voluto: se lo scudo li fermasse,
  due semi interi smetterebbero di essere una strategia.
- **`spawn_card` deve dire dove**: `"where"` fra `top` (default), `random`,
  `bottom`. In cima la carta scende in campo al primo rimpiazzo — giusto per un
  Germoglio, disastroso per il Blocco del Pesca Quattro, che si spegnerebbe la
  catena appena creata. E dice **cosa**: `"card"` per una carta precisa,
  `"cards"` per un sacchetto da cui pescarne una (L'antigh).
- **Il buff appartiene allo slot, non alla carta.** Chi ci passa ne gode, chi se
  ne va se lo lascia alle spalle. Le `source` dei modificatori temporanei sono
  **tre** (`MOD_SLOT`, `MOD_MATCH`, `MOD_BATTLE`) perché `remove_source` lavora
  in blocco: con un'etichetta sola, sostituire il buff di uno slot cancellerebbe
  anche il bonus del Re.
- **Le carte fuori seme** (Jolly, L'antigh, Germoglio, Blocco, Cambia Colore,
  Pesca Quattro) hanno un seme e un valore tutti loro, legati da due liste
  reciproche `rank_ids` / `suit_ids`. `random_card` estrae **una carta**, non un
  seme e poi un valore: altrimenti uscirebbero coppie che non esistono e i mazzi
  verrebbero più corti della ricetta.
- **`burn` è il verbo del controllo**: scarta la carta avversaria più vicina a
  partire senza farla risolvere, e la costringe a pescare. Attacca il mazzo, non
  la vita.
- **`recycle` e `recover` sono i due modi di allontanare il deck-out.** Il
  contatore sta in `Card.uses` e non va azzerato: ogni battaglia gioca con cloni.
- **`haste` non risolve a catena.** Una carta portata a zero parte al tick dopo,
  altrimenti due sproni si rimbalzerebbero l'attivazione all'infinito.
- **Le carte di campagna costano di più** (`shop.card_cost.family_multiplier`).
  Non è tematico: sono strutturalmente più forti perché consumano meno mazzo. Se
  togli quel moltiplicatore, la città smette di avere senso.
- **L'ultima carta spara sempre**: l'effetto si risolve, poi scatta il deck-out.
- I due lati si scorrono sempre nello stesso ordine (giocatore, poi avversario,
  slot per slot): è quello che tiene in piedi il determinismo.
- **Due resolver da ripulire**, non uno: quello del `Duel` e quello
  dell'`EventBook`. `play.gd::_exit_tree()` li chiude entrambi.
- I glifi dei semi sono `♠♥♣♦` e `▲●◼◆`. **Niente emoji**: il font di Godot non
  le ha e su web diventano quadratini.
