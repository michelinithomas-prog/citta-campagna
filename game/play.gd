extends Control
## Il ciclo della partita: incontro → bottega → battaglia → round successivo.
##
## Qui non c'è nessuna regola di gioco. Le regole stanno in game/logic/: questa
## è la scena, e fa tre cose — costruisce i nodi, fa scorrere il tempo nel
## _process, e passa i risultati al RunState.
##
## Le tre schermate seguono le bozze di layout:
##   bottega   — vetrina di carte, reliquie e innesti; mazzo e reliquie a richiesta
##   battaglia — barre della vita a tutta larghezza, informazioni ai lati
##   incontro  — testo e scelte a sinistra, illustrazione a destra

enum Phase { EVENT, SHOP, PREVIEW, BATTLE }

## Cosa sta aspettando un bersaglio nel mazzo: niente, una rimozione, o l'innesto
## numero N della vetrina.
enum Pending { NONE, REMOVE, SEAL }

## Quali pannelli a scomparsa sono aperti sopra la bottega.
enum Overlay { NONE, DECK, RELICS }

var phase: Phase = Phase.SHOP

## Alzata **prima** di aggiungere la scena all'albero, salta ogni dialogo.
## La usano gli strumenti di `tools/` che devono arrivare a una schermata
## precisa: l'introduzione dura centoventi battute, e nessuno di loro sta
## provando quelle. In partita resta sempre falsa.
var senza_dialoghi := false

var run: RunState
var market: Market
var events: EventBook
var duel: Duel
var player: Side
var opponent: Side

var _pending: Pending = Pending.NONE
var _pending_seal := -1
var _overlay: Overlay = Overlay.NONE

# --- musica ---------------------------------------------------------------
#
# Due letti, non tre: la stessa armonia, più svelta e in minore quando si
# gioca. Sono nomi, non percorsi — li risolve Audio in game/audio/, e il
# giorno che al posto del file generato ne arriva uno registrato non cambia
# niente qui. Audio.music() è idempotente sul nome, quindi rientrare in
# bottega dopo un incontro non fa ripartire la traccia da capo.
const MUSICA_BOTTEGA := "musica_bottega"
const MUSICA_BATTAGLIA := "musica_battaglia"

# --- nodi della schermata ------------------------------------------------
#
# REGOLA, pagata cara due volte: qui stanno SOLO i quattro contenitori stabili,
# che nessuno svuota mai, più i nodi creati dentro il pannello che li ospita.
# Un nodo tenuto in una variabile membro e infilato dentro un contenitore che
# poi viene ripulito con _clear() viene liberato insieme a lui, e al giro dopo
# ogni riga che lo tocca è un errore che interrompe la funzione a metà.
# Tutto ciò che si ridisegna nasce dentro la funzione che lo ridisegna.
var _shop_panel: VBoxContainer
var _battle_panel: VBoxContainer
var _event_panel: VBoxContainer
## La scheda dell'avversario, fra la bottega e la battaglia.
var _preview_panel: VBoxContainer
var _overlay_panel: PanelContainer
## Il velo su cui poggia il pannello del mazzo. È un livello a sé, non una riga
## della colonna: vedi `_build_layout`.
var _overlay_layer: ColorRect
## Il riepilogo di fine round e il velo che lo stacca dalla battaglia. Anche
## questi due nascono una volta sola: è il contenuto a rifarsi ogni round.
var _round_panel: VBoxContainer
var _round_layer: ColorRect
## L'illustrazione dietro a tutto, una per fase. Vedi `SFONDI`.
var _sfondo: TextureRect
## La scheda che si apre passando il mouse su una carta. È una sola per tutta la
## partita e non sta dentro nessun pannello: nasce fuori da tutto, così nessun
## `_clear()` la porta via mentre è aperta.
var _detail: CardDetail
## Il fumetto della storia, sopra a tutto il resto.
var _dialogo: Dialogo
## Il regista delle animazioni di battaglia. Come i quattro pannelli qui sopra
## nasce una volta sola e nessuno lo svuota: sta **fuori** da `_battle_panel`
## apposta, perché i nodi effimeri che possiede non devono poter essere liberati
## dal `_clear()` di fine round mentre qualcuno li sta animando.
var _gesti: Gesti
## Chi ha sparato in questo istante, per attribuirgli il numero del colpo:
## `{"side": Side, "slot": int}`, vuoto quando il danno non ha un autore — il
## veleno e il sanguinamento non ce l'hanno, e non devono averne uno inventato.
var _autore := {}
## L'ultimo valore visto di vita e scudo per lato, per calcolare la differenza.
## Il numero che si mostra è la **conseguenza vera**, dopo lo scudo e dopo la
## catena, non quello stampato sulla carta.
var _hp_visti := {}
var _scudi_visti := {}
## Cosa fare quando la scena di dialogo finisce. Una scena non ferma la partita:
## la mette in coda, e chi l'ha aperta dice qui come si riprende.
var _dopo_il_dialogo: Callable
## Vera se la battaglia appena finita era la partita di prova contro GiGi. Va
## letta prima di `finish_round`, che è chi spegne `run.tutorial`.
var _era_il_tutorial := false

## Creato da _build_battle_view, vive quanto la schermata di battaglia.
var _panels: Array[SidePanel] = []
var _views := {}  # Side -> Array[CardView]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Il vestito di questa scena. Si sovrappone al tema del core senza
	# sostituirlo, e sopravvive a F5 (che riassegna solo il tema della radice).
	theme = Hud.tema()

	# Se c'è una partita salvata e si è arrivati qui da "Continua", si riprende
	# da lì; altrimenti si comincia da capo.
	run = _carica_o_comincia()
	market = Market.new(Rng.stream)
	events = EventBook.new(Rng.stream)

	_build_layout()
	_register_debug()

	# La storia prima di tutto: alla prima partita si comincia dal bar. Chi
	# riprende da "Continua" se l'è già vista, e `_apri_dialogo` lo sa.
	if not _apri_dialogo("inizio", _dopo_intro):
		_dopo_intro()


## Dove si va dopo l'introduzione. **Non in bottega**: la prima cosa che si fa è
## la partita di prova contro GiGi, e la Bottega Angelini si apre solo dopo.
func _dopo_intro() -> void:
	# Chi salta i dialoghi salta anche la partita di prova: gli strumenti di
	# `tools/` vogliono il ciclo normale, e il tutorial non è il ciclo normale.
	# Il regalo però si versa lo stesso, o misurerebbero un mazzo che nessun
	# giocatore ha mai in mano.
	if senza_dialoghi and run.tutorial:
		run.tutorial = false
		run.regala_le_carte_del_tutorial()

	if not run.tutorial:
		_enter_shop()
		return
	if not _apri_dialogo("tutorial_inizio", _start_battle):
		_start_battle()


## Il menu decide: se ha premuto "Continua" alza la bandiera, e qui si riprende
## la partita interrotta invece di cominciarne una nuova.
func _carica_o_comincia() -> RunState:
	if not bool(Save.get_value("options.resume", false)):
		return RunState.new(Rng.stream)

	Save.set_value("options.resume", false)
	var salvata := RunState.load_saved(Rng.stream)
	if salvata == null:
		return RunState.new(Rng.stream)

	Events.toast(tr("Ripresa dal round %d") % salvata.round_number, "info")
	return salvata


func _process(delta: float) -> void:
	# Mentre GiGi parla il tavolo sta fermo. È quello che permette alla lezione
	# di indicare una carta e dire "guarda quella": se intanto il tempo corresse,
	# la carta indicata sarebbe già stata scartata a metà frase.
	if _dialogo != null and _dialogo.visible:
		return
	if phase != Phase.BATTLE or duel == null or duel.is_over:
		return
	duel.advance(delta)
	# I gesti avanzano **qui**, accanto alla simulazione, e non per conto loro:
	# così quando il tavolo si ferma — un dialogo, la fine della battaglia — si
	# fermano anche loro, senza che nessuno debba ricordarsene.
	_gesti.passo(delta)
	# Il resto del clock è quanto tempo simulato è passato dall'ultimo tick: con
	# quello le barre dell'attesa si muovono alla velocità dello schermo invece
	# che a venti scatti al secondo.
	var anticipo := duel.clock.resto()
	for side in _views:
		for view in _views[side]:
			view.refresh(delta, anticipo)
	for panel in _panels:
		panel.refresh()


func _exit_tree() -> void:
	# Due resolver, non uno: gli handler catturano l'oggetto che li ospita e
	# quello degli eventi è il facile da dimenticare.
	if duel != null:
		duel.resolver.clear_handlers()
	if events != null:
		events.clear_handlers()


# --- fasi ----------------------------------------------------------------

## Prima della bottega può capitare un incontro. Non al primo round, e non
## sempre: se capitasse ogni volta smetterebbe di essere un incontro.
func _enter_shop() -> void:
	if events.should_trigger(run.round_number, run):
		var event := events.draw(run.round_number, run)
		if not event.is_empty():
			_show_event(event)
			return
	_apri_bottega()


func _apri_bottega() -> void:
	phase = Phase.SHOP
	Audio.music(MUSICA_BOTTEGA)
	_aggiorna_sfondo()
	_pending = Pending.NONE
	_overlay = Overlay.NONE
	_shop_panel.visible = true
	_battle_panel.visible = false
	_event_panel.visible = false
	_preview_panel.visible = false
	_chiudi_overlay()

	# `run` va passato sempre: è così che la bottega sa quali reliquie hai già
	# (non le rimette in vendita) e quanto sconto ti spetta.
	market.roll(run.round_number, run)
	_salva()
	_refresh_shop()

	# La lezione sulla bottega si apre **sopra** la bottega già costruita: GiGi
	# parla di quello che si vede dietro di lui, non di un'idea astratta.
	_apri_dialogo(_quando_della_bottega())


## Le due botteghe che hanno una lezione: la prima, e quella dove cominciano a
## comparire in vetrina i mazzi che ancora non sai leggere.
func _quando_della_bottega() -> String:
	if run.wins == 0:
		return "prima_bottega"
	if run.wins == 2:
		return "terza_bottega"
	return ""


func _start_battle() -> void:
	phase = Phase.BATTLE
	Audio.music(MUSICA_BATTAGLIA)
	_aggiorna_sfondo()
	_pending = Pending.NONE
	_overlay = Overlay.NONE
	_shop_panel.visible = false
	_event_panel.visible = false
	_preview_panel.visible = false
	_chiudi_overlay()
	_battle_panel.visible = true

	var recipe := run.opponent_for_round()
	var slots := Cfg.get_int("player.board_size", 5)

	# Le reliquie cambiano i miei numeri, non i suoi: l'avversario gioca sempre
	# con la plancia base.
	# Quello che un incontro ti ha lasciato addosso vale per **questa** battaglia
	# e poi si consuma: ci arrivi acciaccato dal temporale, o con le carte
	# ancora intorpidite dalla scossa nel vicolo.
	var strascico: Dictionary = run.next_battle.duplicate()
	run.next_battle.clear()

	player = Side.new("Tu", run.battle_deck(), Rng.stream, {
		"hp": maxi(int(round(run.max_hp * float(strascico.get("hp_mult", 1.0)))), 1),
		"board_size": slots + run.board_bonus(),
		"shield": run.start_shield(),
		"status_resist": run.status_resist(),
		"combo": run.start_combo(),
		"is_player": true,
	})
	# Le carte nate in battaglia devono nascere con i bonus della run addosso:
	# il Duel non conosce la RunState, quindi il costruttore glielo passiamo noi.
	player.card_maker = run.make_card
	# La ricetta passa da `ricetta_svelata`: finché One e Gaiofanamon non sono
	# stati presentati, nemmeno l'avversario li gioca.
	opponent = Side.new(String(recipe.get("name", "Avversario")),
		CardLibrary.generate(Rng.stream, run.ricetta_svelata(recipe)), Rng.stream,
		{"hp": int(recipe.get("hp", 40)), "shield": int(recipe.get("shield", 0)), "board_size": slots})

	duel = Duel.new(player, opponent, Rng.stream, Cfg.get_float("battle.tick", 0.05))
	# Dopo il Duel, non prima: la plancia si riempie dentro il suo costruttore, e
	# paralizzare degli slot vuoti non paralizza niente.
	if strascico.has("paralyzed"):
		player.paralyze(float(strascico["paralyzed"]))
	duel.speed_up(_velocita_scelta())
	duel.ended.connect(_on_ended)
	duel.card_activated.connect(_on_card_activated)
	duel.card_burned.connect(_on_card_burned)

	# La vista segue il rimpiazzo, non l'attivazione: quando la carta parte è
	# ancora nello slot, il nuovo inquilino arriva solo dopo lo scarto.
	for side in [player, opponent]:
		side.slot_filled.connect(func(slot: int, _card: Card) -> void:
			_refresh_slot(side, slot)
		)

	_build_battle_view()

	# Gli agganci delle animazioni vengono **dopo** `_build_battle_view`, e non
	# è un dettaglio d'ordine: prima di quella riga `_views` e `_panels`
	# contengono ancora le viste della battaglia scorsa. Non sono nodi liberati
	# — il pannello viene nascosto, non svuotato — quindi `is_instance_valid`
	# non se ne accorge e un gesto partirebbe su coordinate plausibili e
	# sbagliate. Anche lo specchietto di vita e scudo si prende qui, dove è
	# coerente con le connessioni: gli effetti d'ingresso risolti dentro il
	# costruttore del Duel non producono animazione, ed è giusto così — la
	# battaglia non era ancora cominciata.
	_gesti.svuota()
	_autore.clear()
	_hp_visti = {player: player.hp, opponent: opponent.hp}
	_scudi_visti = {player: player.shield(), opponent: opponent.shield()}
	duel.card_left.connect(_on_card_left)
	# Non c'è nessun aggancio a `combo_changed`, ed è una scelta. La catena
	# scatta 6-10 volte a battaglia con un mazzo che ci punta (misurato): abbastanza
	# rara da meritare un gesto. Ma in battaglia **non ha un organo che la
	# mostri** — il riquadro informazioni dice nome, carte in mazzo e scarti — e
	# l'unica cosa che si può accendere sono le carte del lato, che però stanno
	# già dicendo un'altra cosa con il colore del loro effetto. Accenderle
	# d'ottone significherebbe cancellare quel colore per parlare di un numero
	# scritto da nessuna parte. Prima il contatore nell'HUD, poi la sua animazione.
	for side in [player, opponent]:
		side.hp_changed.connect(_on_hp_changed.bind(side))
		side.shield_changed.connect(_on_shield_changed.bind(side))

	Audio.sfx("confirm")

	# La lezione sul tavolo si apre **sopra il tavolo già apparecchiato**, con le
	# carte in campo e le barre piene. Il duello resta fermo finché GiGi parla:
	# se ne occupa `_process`.
	_apri_dialogo("tutorial_tavolo")


## La velocità impostata dal menu, se c'è; altrimenti quella del tuning.
func _velocita_scelta() -> float:
	return float(Save.get_value("options.battle_speed", Cfg.get_float("battle.speed", 1.0)))


func _on_card_activated(side: Side, slot: int, card: Card) -> void:
	Audio.sfx("hit" if side.is_player else "hurt", randf_range(0.92, 1.08), -10.0)

	# Chi spara adesso è questo, e lo resta finché la sua risoluzione non si
	# chiude: è a lui che verranno attribuiti i numeri dei colpi.
	_autore = {"side": side, "slot": slot}

	# Il segnale arriva **prima** di `resolve_all`, quindi in questo istante la
	# vista mostra ancora la carta che sta sparando: il fantasma è una
	# fotografia fedele. È qui, e solo qui, che il problema della sostituzione
	# dentro lo stesso frame si risolve.
	var view := _vista(side, slot)
	if view == null:
		return
	_gesti.stoccata(view.get_global_rect(), card, Gesti.verso_di(card, _casa(side)))
	view.lampeggia(Gesti.tinta_di(card))


## La carta lascia lo slot per una ragione che non è l'attivazione: bruciata,
## rubata o cresciuta di livello. Tre gesti diversi da un handler solo, perché è
## `duel.gd` a tenere la precedenza fra i quattro modi e non vogliamo una
## seconda copia di quella regola qui dentro.
##
## Doppio lavoro: chiude anche la finestra dell'autore. `card_left` arriva dopo
## `resolve_all` e prima di `refill()`, che è il limite superiore esatto — e
## azzerare `_autore` a inizio frame invece che qui produceva cinque
## attribuzioni false in una battaglia, perché a 4× il veleno del tick seguente
## cade nello stesso frame di un'attivazione già avvenuta e ne eredita l'autore.
func _on_card_left(side: Side, slot: int, card: Card, motivo: String) -> void:
	# Bruciatura e furto capitano **dentro** la risoluzione di chi ha sparato:
	# non sono la fine della sua finestra, sono un suo effetto.
	if motivo != Duel.MOTIVO_BRUCIATA and motivo != Duel.MOTIVO_RUBATA:
		if _autore.get("side") == side and int(_autore.get("slot", -1)) == slot:
			_autore.clear()

	if motivo == Duel.MOTIVO_SCARTATA or motivo == Duel.MOTIVO_RICICLATA:
		return  # Il gesto l'ha già fatto `_on_card_activated`.

	var view := _vista(side, slot)
	if view == null:
		return
	_gesti.congedo(view.get_global_rect(), card, motivo, Gesti.verso_di(card, _casa(side)))
	if motivo == Duel.MOTIVO_EVOLUTA:
		view.lampeggia(Hud.ORO)


## Il numero: la conseguenza vera, non quella stampata sulla carta. Passando per
## `hp_changed` arrivano già scontati lo scudo, la catena e le resistenze — e
## arrivano gratis anche il veleno e il sanguinamento, che carta non ne hanno.
func _on_hp_changed(current: int, _massimo: int, chi: Side) -> void:
	var prima := int(_hp_visti.get(chi, current))
	_hp_visti[chi] = current
	var scarto := current - prima
	if scarto == 0:
		return
	_numero_del_colpo(chi, scarto, Hud.DANNO if scarto < 0 else Hud.CURA)


func _on_shield_changed(amount: int, chi: Side) -> void:
	var prima := int(_scudi_visti.get(chi, amount))
	_scudi_visti[chi] = amount
	# Solo lo scudo che si guadagna: quello che si consuma parando è già
	# raccontato dal danno che non è arrivato.
	if amount <= prima:
		return
	_numero_del_colpo(chi, amount - prima, Hud.SCUDO)


## Dove nasce il numero: sulla carta che ha sparato, se ce n'è una. Veleno e
## sanguinamento non hanno un autore e non devono averne uno inventato: il loro
## numero nasce sulla vittima, che è la verità.
func _numero_del_colpo(bersaglio: Side, valore: int, colore: Color) -> void:
	var autore: Side = _autore.get("side")
	var view := _vista(autore, int(_autore.get("slot", -1))) if autore != null else null
	if view == null:
		view = _vista_piu_vicina(bersaglio)
	if view == null:
		return
	var casa := _casa(autore if autore != null else bersaglio)
	_gesti.numero(valore, colore, view.get_global_rect(), -casa)


## Da che parte sta questo schieramento: +1 in basso (il giocatore), −1 in alto.
func _casa(side: Side) -> int:
	return 1 if side != null and side.is_player else -1


func _vista(side: Side, slot: int) -> CardView:
	if side == null:
		return null
	var views: Array = _views.get(side, [])
	if slot < 0 or slot >= views.size():
		return null
	var view: CardView = views[slot]
	return view if is_instance_valid(view) else null


## Un appoggio per i numeri senza autore: lo slot di mezzo del bersaglio.
func _vista_piu_vicina(side: Side) -> CardView:
	var views: Array = _views.get(side, [])
	if views.is_empty():
		return null
	return _vista(side, views.size() / 2)


func _on_card_burned(_side: Side, _slot: int, _card: Card) -> void:
	Audio.sfx("explosion", 1.1, -8.0)


## Prima si fa avanzare la partita, poi si fa la faccia contenta.
##
## L'ordine non è estetico: questa funzione è un handler di segnale, e in
## GDScript un errore a metà la interrompe e basta — il gioco resta in piedi ma
## la partita no. Con la UI in cima, un nodo liberato bastava a piantare tutto
## sulla schermata di battaglia.
func _on_ended(won: bool, reason: String) -> void:
	# Il numero va letto adesso: finish_round fa avanzare il contatore, e il
	# messaggio parla del round appena giocato, non del prossimo.
	var numero := run.round_number

	# L'oro raccolto dalle carte denari durante la battaglia entra in cassa.
	var raccolto := player.gold()
	run.earn(raccolto)

	# Le creature cresciute restano cresciute, vinta o persa che sia. Prima del
	# salvataggio, che arriva fra poche righe.
	var cresciute := run.evolvi(duel.evoluzioni)
	var vite_prima := run.lives
	# Letto prima di chiudere il round: è `finish_round` a spegnere il tutorial,
	# e il riepilogo che arriva dopo deve sapere che partita è stata.
	_era_il_tutorial = run.tutorial
	var continua := run.finish_round(won)

	# Si salva subito, non all'ingresso in bottega: fra qui e là c'è la pausa e
	# il riepilogo, e chi chiude la finestra in quel momento perderebbe il round
	# che ha appena vinto.
	if continua:
		_salva()

	_aggiorna_schermata_finale(won, reason)

	# Taglio netto ai gesti, e **dopo** la schermata finale, non prima: quella
	# funzione ripassa da `_refresh_slot` su tutti gli slot, e ogni passaggio
	# rimette in moto un ingresso. Da qui in avanti `_process` esce su
	# `duel.is_over` e non fa più girare niente, quindi un gesto lasciato a metà
	# ci resta: un fantasma appeso a mezz'aria e le carte storte e sbiadite,
	# proprio sull'immagine che il giocatore guarda più a lungo di tutte.
	_autore.clear()
	_gesti.svuota()
	for lato in _views:
		for vista in _views[lato]:
			if is_instance_valid(vista):
				(vista as CardView).concludi()

	# Un respiro prima del riepilogo: la battaglia finisce nell'istante in cui
	# l'ultimo colpo va a segno, e coprirla subito non lascia vedere com'è andata.
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return

	_mostra_fine_round(won, reason, numero, maxi(vite_prima - run.lives, 0), raccolto,
		cresciute, continua)


## Il riepilogo di fine round: chi ha vinto, perché, e quanto è costato.
##
## Esiste per un numero solo: **le vite perse**. Una sconfitta non ne toglie
## sempre una — `RunState.life_cost()` le fa costare di più round dopo round — e
## fino a qui quel numero non era scritto da nessuna parte: il giocatore vedeva
## il contatore delle vite calare di tre senza sapere perché.
##
## Si va avanti con un click e non da soli: è l'unico momento della partita in
## cui c'è qualcosa da leggere, e un riepilogo che sparisce dopo un secondo e
## mezzo non è un riepilogo.
func _mostra_fine_round(won: bool, reason: String, numero: int, vite_perse: int,
		raccolto: int, cresciute: int, continua: bool) -> void:
	_clear(_round_panel)

	# La partita di prova non è un round: non ha un numero, non fa vincere niente
	# e non toglie niente. Chiamarla "Round 1 perso" spaventerebbe per sbaglio.
	var prova := _era_il_tutorial
	# Due frasi intere invece di "Round %d %s" con l'aggettivo infilato dentro:
	# un participio non è una parola che si traduce da sola.
	var testa := "Partita di prova"
	if not prova:
		testa = (tr("Round %d vinto") if won else tr("Round %d perso")) % numero
	var titolo := Ui.label(testa, Hud.TESTO_TITOLONE,
		Hud.OTTONE if prova else (Hud.CURA if won else Hud.DANNO))
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_panel.add_child(titolo)

	var motivo := Ui.dim(_verdict(won, reason), Hud.TESTO)
	motivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_panel.add_child(motivo)
	_round_panel.add_child(Ui.spacer(Hud.PAD_SMALL))

	if prova:
		var nota := Ui.dim("Non conta: nessuna vittoria, nessuna vita.", Hud.TESTO)
		nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_round_panel.add_child(nota)

	if raccolto > 0 and not prova:
		_round_panel.add_child(_riga_esito("Oro raccolto in battaglia", "+%d" % raccolto, Hud.ORO))
	if won and not prova:
		_round_panel.add_child(_riga_esito("Premio del round",
			"+%d" % Cfg.get_int("shop.win_bonus", 3), Hud.ORO))
	# La crescita è successa in battaglia ma si vede nel mazzo, e fra le due cose
	# c'è questo schermo: se non lo dice qui, il giocatore trova una carta diversa
	# in bottega senza sapere da dove arriva.
	if cresciute > 0:
		_round_panel.add_child(_riga_esito(
			Testo.plurale(cresciute, "Creatura cresciuta", "Creature cresciute"),
			"+%d" % cresciute, Hud.CURA))
	if vite_perse > 0:
		_round_panel.add_child(_riga_esito("Vite perse", "−%d" % vite_perse, Hud.DANNO))
	if not prova:
		_round_panel.add_child(_riga_esito("Vite rimaste", str(maxi(run.lives, 0)),
			Hud.CURA if run.lives > 0 else Hud.DANNO))

	_round_panel.add_child(Ui.spacer(Hud.PAD_SMALL))
	var avanti := Ui.button("Continua" if continua else "Vedi il risultato",
		func() -> void: _chiudi_fine_round(continua))
	avanti.custom_minimum_size = Vector2(220, 44)
	_round_panel.add_child(Ui.center_row(avanti))

	_round_layer.visible = true
	avanti.grab_focus()


func _chiudi_fine_round(continua: bool) -> void:
	_round_layer.visible = false
	if continua:
		# Dopo la partita di prova GiGi consegna le carte di città: la scena e il
		# regalo sono la stessa cosa, e il regalo si versa quando la scena finisce.
		if _era_il_tutorial:
			_era_il_tutorial = false
			if not _apri_dialogo("dopo_tutorial", _festeggia_il_regalo):
				_festeggia_il_regalo()
			return

		# La prima vittoria ha una scena sua: è lì che il gioco spiega l'AAG e
		# perché tutto questo sta succedendo.
		var quando := "dopo_vittoria_1" if run.wins == 1 else ""
		if not _apri_dialogo(quando, _enter_shop):
			_enter_shop()
		return

	# La partita è finita: il salvataggio non serve più a nessuno.
	_cancella_salvataggio()
	if not _apri_dialogo("vittoria" if run.victory else "sconfitta", _vai_al_finale):
		_vai_al_finale()


## La schermata finale, dopo che la storia ha detto la sua.
##
## Si vince battendo l'ultimo avversario, punto: arrivarci con zero vite in
## tasca è un finale magro, non una sconfitta.
func _vai_al_finale() -> void:
	# Il Router sa solo "vinto sì o no", e i finali sono tre: quale sia lo si
	# lascia scritto qui, e `game_over.gd` lo rilegge.
	Save.set_value(RunState.CHIAVE_FINALE, run.finale())
	Router.game_over(run.victory, run.stats())


## Una riga del riepilogo: cosa è successo a sinistra, quanto a destra.
func _riga_esito(nome: String, valore: String, colore: Color) -> Control:
	return Ui.hbox([
		Ui.dim(nome, Hud.TESTO),
		Ui.spacer(),
		Ui.label(valore, Hud.TESTO, colore),
	])


func _aggiorna_schermata_finale(won: bool, reason: String) -> void:
	for side in _views:
		for slot in _views[side].size():
			_refresh_slot(side, slot)
	# Niente toast dell'esito: un secondo dopo arriva il riepilogo e lo dice più
	# in grande, e i due finivano a schermo insieme. Resta lo scossone, che è
	# l'unica cosa che si sente prima di leggere.
	# Un gesto corto, non la cadenza intera: `win`/`lose` è il suono della RUN,
	# e lo suona Router quando si apre la schermata finale. Suonandolo anche
	# qui si sentiva due volte lo stesso valzer a un secondo di distanza.
	Audio.sfx("confirm" if won else "cancel")
	if not won:
		Events.shake(8.0, 0.3)


func _verdict(won: bool, reason: String) -> String:
	if reason == Side.REASON_DECKOUT:
		return "Vinto: gli sono finite le carte." if won else "Perso: ti sono finite le carte."
	if reason == Side.REASON_HP:
		return "Vinto: l'hai steso." if won else "Perso: ti ha steso."
	return "Vinto ai punti." if won else "Perso ai punti."


# --- salvataggio ---------------------------------------------------------

## Si salva a ogni passaggio dalla bottega e dopo ogni acquisto: se il giocatore
## chiude la finestra a metà round non deve perdere il lavoro fatto.
func _salva() -> void:
	if run != null:
		run.save()


func _cancella_salvataggio() -> void:
	RunState.clear_save()


# --- la scheda dell'avversario -------------------------------------------

## Chi hai davanti, prima di decidere. Ritratto, numeri, e soprattutto **da che
## mazzi pesca**: è quello a dire che partita sarà, e sapere che il Fabbro gioca
## carte innestate cambia cosa vale la pena comprare prima di sedersi.
##
## Si può anche tornare indietro: la bottega resta com'era — la vetrina non si
## rimescola — quindi il ripensamento non costa niente. È voluto: la scheda serve
## a decidere, e una decisione senza ritorno non è una decisione.
func _mostra_avversario() -> void:
	phase = Phase.PREVIEW
	_pending = Pending.NONE
	_overlay = Overlay.NONE
	_aggiorna_sfondo()
	_shop_panel.visible = false
	_battle_panel.visible = false
	_event_panel.visible = false
	_chiudi_overlay()
	_preview_panel.visible = true

	_clear(_preview_panel)
	var recipe := run.opponent_for_round()

	var testo := Ui.label(String(recipe.get("text", "")), Palette.FONT_BODY)
	testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	testo.custom_minimum_size.x = 460

	var combatti := Ui.button("Combatti", _start_battle)
	combatti.custom_minimum_size.y = 48

	var sinistra := Ui.vbox([
		Ui.panel(Ui.margin(testo, Palette.PAD)),
		Ui.spacer(Palette.PAD_SMALL),
		_numeri_avversario(recipe),
		Ui.spacer(Palette.PAD_SMALL),
		_archetipo_avversario(recipe),
		Ui.spacer(Palette.PAD),
		combatti,
		Ui.button("Torna alla bottega", _apri_bottega),
	], Palette.PAD_SMALL)
	sinistra.custom_minimum_size.x = 480

	# Il ritratto è quadrato come i file: una cornice 16:9 gli lascerebbe due
	# bande vuote ai lati.
	var ritratto := _illustrazione({
		"image": recipe.get("portrait", ""),
		"symbol": recipe.get("symbol", "★"),
		"name": recipe.get("name", ""),
	}, Vector2(360, 360))

	_preview_panel.add_child(Ui.center_row(Ui.heading(
		tr("Vittoria %d di %d — %s") % [run.wins + 1, run.wins_needed(),
			tr(String(recipe.get("name", "Qualcuno")))]
	)))
	_preview_panel.add_child(Ui.center(Ui.hbox([sinistra, ritratto], Palette.PAD)))


## Vita, scudo, quante carte ha e quanto grosse le gioca.
func _numeri_avversario(recipe: Dictionary) -> Control:
	var fascia: Array = recipe.get("value_range", [])
	var righe: Array[Control] = [
		_riga_numero("Vita", "%d" % int(recipe.get("hp", 0)), Palette.DANGER),
		_riga_numero("Scudo", "%d" % int(recipe.get("shield", 0)), Palette.INFO),
		_riga_numero("Carte nel mazzo", "%d" % int(recipe.get("deck_size", 0)), Palette.TEXT),
		_riga_numero("Valori", "%d-%d" % [int(fascia[0]), int(fascia[1])] if fascia.size() > 1 else "tutti",
			Palette.TEXT_DIM),
	]
	return Ui.panel(Ui.margin(Ui.vbox(righe, 2), Palette.PAD_SMALL))


## La riga di un mazzo che non è ancora stato presentato. Nessuna barra e nessun
## numero: solo il fatto che c'è qualcosa che non sai ancora leggere.
func _riga_censurata() -> Control:
	var nome := Ui.label("???", Palette.FONT_SMALL, Palette.TEXT_MUTED)
	nome.custom_minimum_size.x = 110
	var nota := Ui.dim("un mazzo che non conosci", Palette.FONT_SMALL)
	nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Ui.hbox([nome, nota], Palette.PAD_SMALL)


func _riga_numero(etichetta: String, valore: String, tinta: Color) -> Control:
	var sinistra := Ui.dim(etichetta, Palette.FONT_SMALL)
	sinistra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Ui.hbox([sinistra, Ui.label(valore, Palette.FONT_BODY, tinta)], Palette.PAD_SMALL)


## Da che mazzi pesca, e cosa sa fare oltre alle carte. È la parte che conta:
## i numeri dicono quanto regge, questa dice **che partita sarà**.
func _archetipo_avversario(recipe: Dictionary) -> Control:
	var pesi: Dictionary = recipe.get("weights", {})
	var totale := 0.0
	for chiave in pesi:
		totale += maxf(float(pesi[chiave]), 0.0)

	# I mazzi non ancora svelati non entrano nel conto: l'avversario non li gioca
	# davvero (`RunState.ricetta_svelata`), quindi le percentuali qui sotto sono
	# quelle vere di quello che scenderà in campo.
	totale = 0.0
	for chiave in pesi:
		if run.mazzo_svelato_per_id(String(chiave)):
			totale += maxf(float(pesi[chiave]), 0.0)

	var righe: Array[Control] = [Ui.dim("GIOCA", Palette.FONT_SMALL)]
	for family in Content.list("families"):
		var id := String(family.get("id", ""))
		var quota := maxf(float(pesi.get(id, 0.0)), 0.0)
		if quota <= 0.0:
			continue

		# Un mazzo che il gioco non ti ha ancora presentato non si nomina: resta
		# una riga di punti interrogativi. Non è una percentuale nascosta — quelle
		# carte in campo non ci vanno — è il segnale che c'è dell'altro.
		if not run.mazzo_svelato(family):
			righe.append(_riga_censurata())
			continue
		if totale <= 0.0:
			continue

		var percentuale := quota / totale
		var barra := Ui.bar(0.0, 1.0, CardView.color_of(String(family.get("color", "accent"))), 10)
		barra.value = percentuale
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var nome := Ui.label(String(family.get("name", id)), Palette.FONT_SMALL)
		nome.custom_minimum_size.x = 110
		righe.append(Ui.hbox([
			nome, barra, Ui.dim("%d%%" % int(round(percentuale * 100.0)), Palette.FONT_SMALL),
		], Palette.PAD_SMALL))

	for tratto in _tratti_avversario(recipe):
		var riga := Ui.label("• %s" % tratto, Palette.FONT_SMALL, Palette.GOLD)
		riga.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		riga.custom_minimum_size.x = 1
		riga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		righe.append(riga)

	return Ui.panel(Ui.margin(Ui.vbox(righe, 4), Palette.PAD_SMALL))


## Di chi parla un tratto: tutte le carte dell'avversario, quelle di un mazzo, o
## quelle di un seme — e un'etichetta si dice come un seme, quindi le due
## condividono la frase.
enum Chi { TUTTE, MAZZO, GRUPPO }


## La frase intera che dice cosa fa quel gruppo di carte, col numero già dentro.
##
## Tre frasi e non un soggetto cucito davanti a un predicato: «le sue carte di
## %s» non è una frase — le manca il verbo, e la lingua che il verbo lo mette in
## fondo non saprebbe dove rimetterlo.
func _tratto(chi: Chi, nome: String, quanto: Variant,
		tutte: String, mazzo: String, gruppo: String) -> String:
	if chi == Chi.MAZZO:
		return tr(mazzo) % [nome, quanto]
	if chi == Chi.GRUPPO:
		return tr(gruppo) % [nome, quanto]
	return tr(tutte) % quanto


## Le abilità: quello che l'avversario ha **oltre** alle carte che pesca. Sono le
## due leve delle ricette — i bonus su tutto il mazzo e gli innesti — dette in
## italiano, perché una scheda che mostrasse `{"family":"briscola"}` non
## servirebbe a nessuno.
##
## Escono **già tradotte**: chi le mostra le infila in `"• %s"`, e da lì in poi
## nessuno le cerca più in catalogo.
func _tratti_avversario(recipe: Dictionary) -> Array[String]:
	var out: Array[String] = []

	for rule in recipe.get("rules", []):
		if not rule is Dictionary:
			continue
		var regola: Dictionary = rule
		var chi := Chi.TUTTE
		var nome := ""
		if regola.has("family"):
			var id := String(regola["family"])
			var family: Dictionary = Content.entry("families", id) if Content.has("families", id) else {}
			chi = Chi.MAZZO
			nome = tr(String(family.get("name", id)))
		elif regola.has("suit"):
			var sid := String(regola["suit"])
			var suit: Dictionary = Content.entry("suits", sid) if Content.has("suits", sid) else {}
			chi = Chi.GRUPPO
			nome = tr(String(suit.get("name", sid)))
		elif regola.has("tag"):
			chi = Chi.GRUPPO
			nome = tr(String(regola["tag"]))

		if regola.has("value_add"):
			out.append(_tratto(chi, nome, int(regola["value_add"]),
				"le sue carte valgono %+d",
				"le sue carte di %s valgono %+d",
				"le sue %s valgono %+d"))
		if regola.has("value_mult"):
			out.append(_tratto(chi, nome, float(regola["value_mult"]),
				"le sue carte valgono ×%.1f",
				"le sue carte di %s valgono ×%.1f",
				"le sue %s valgono ×%.1f"))
		if regola.has("cooldown_scale"):
			out.append(_tratto(chi, nome,
				int(round((1.0 - float(regola["cooldown_scale"])) * 100.0)),
				"le sue carte si fanno aspettare il %d%% in meno",
				"le sue carte di %s si fanno aspettare il %d%% in meno",
				"le sue %s si fanno aspettare il %d%% in meno"))

	var innesti: Array = recipe.get("seals", [])
	if not innesti.is_empty():
		var ogni := maxi(int(recipe.get("seal_every", 3)), 1)
		var quanti := maxi(int(recipe.get("seals_per_card", 1)), 1)
		var nomi: Array[String] = []
		for seal_id in innesti:
			var seal: Dictionary = Content.entry("seals", String(seal_id)) if Content.has("seals", String(seal_id)) else {}
			nomi.append(tr(String(seal.get("name", seal_id))))
		out.append(Testo.plurale(quanti,
			"una carta su %d porta %d innesto: %s",
			"una carta su %d porta %d innesti: %s") % [ogni, quanti, ", ".join(nomi)])

	return out


# --- incontri ------------------------------------------------------------

## Testo e scelte a sinistra, illustrazione a destra, come nella bozza.
func _show_event(event: Dictionary) -> void:
	phase = Phase.EVENT
	_aggiorna_sfondo()
	_shop_panel.visible = false
	_battle_panel.visible = false
	_preview_panel.visible = false
	_chiudi_overlay()
	_event_panel.visible = true
	_clear(_event_panel)

	var testo := Ui.label(String(event.get("text", "")))
	testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	testo.custom_minimum_size = Vector2(520, 150)
	testo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var scelte: Array[Control] = []
	var choices: Array = event.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var index := i
		var bottone := Ui.button(String(choice.get("label", "…")), func() -> void: _on_event_choice(event, index))
		bottone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottone.tooltip_text = String(choice.get("hint", ""))
		scelte.append(Ui.vbox([bottone, Ui.dim(String(choice.get("hint", "")))], 2))

	var sinistra := Ui.vbox([Ui.panel(Ui.margin(testo, Palette.PAD))] + scelte, Palette.PAD_SMALL)
	sinistra.custom_minimum_size.x = 540

	_event_panel.add_child(Ui.center_row(Ui.heading(String(event.get("name", "Un incontro")))))
	_event_panel.add_child(Ui.hbox([sinistra, _illustrazione(event)], Palette.PAD))
	Audio.sfx("confirm")


## Quanto è grande a schermo l'illustrazione di un incontro. **16:9 come i file**
## (1024×576): una cornice di proporzioni diverse lascia due bande nere ai lati,
## perché il disegno dentro si adatta senza deformarsi e non riempie il resto.
const ILLUSTRAZIONE := Vector2(512, 288)


## Lo spazio dell'illustrazione: un campo `"image"` nel JSON dell'incontro — o in
## quello di una singola scelta, per l'esito. Senza disegno resta il simbolo, che
## tiene il posto senza far saltare il layout.
func _illustrazione(source: Dictionary, misura: Vector2 = ILLUSTRAZIONE) -> PanelContainer:
	var contenuto: Control
	var percorso := String(source.get("image", ""))
	if percorso != "" and ResourceLoader.exists(percorso):
		var texture := TextureRect.new()
		texture.texture = load(percorso)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contenuto = texture
	else:
		var simbolo := Ui.label(String(source.get("symbol", "❦")), 88, Palette.TEXT_MUTED)
		simbolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var didascalia := Ui.dim(String(source.get("name", "")), Palette.FONT_SMALL)
		didascalia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contenuto = Ui.center(Ui.vbox([simbolo, didascalia], 4))

	var cornice := PanelContainer.new()
	cornice.add_theme_stylebox_override("panel", ThemeBuilder.box(
		Palette.BG_DEEP, Palette.BORDER, Palette.RADIUS, Palette.BORDER_WIDTH
	))
	cornice.custom_minimum_size = misura
	cornice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cornice.add_child(contenuto)
	return cornice


func _on_event_choice(event: Dictionary, index: int) -> void:
	var lines := events.choose(event, index, run)
	_clear(_event_panel)

	# Un incontro può costare l'ultima vita — o chiudere la partita da sé: c'è
	# una scelta che la finisce, ed è la scelta giusta. Senza questo controllo la
	# run proseguirebbe fino alla prossima sconfitta.
	if run.abandoned or run.lives <= 0:
		Events.toast("La partita finisce qui" if run.abandoned else "Non ti restano vite", "bad")
		_cancella_salvataggio()
		_vai_al_finale()
		return

	var righe: Array[Control] = [Ui.center_row(Ui.heading(String(event.get("name", ""))))]

	# L'esito ha il suo disegno quando la scelta se lo porta dietro: certe scelte
	# cambiano la scena — la partita che finisce, l'avversario che rovescia il
	# tavolo — e mostrarle ancora l'illustrazione dell'incontro le sprecherebbe.
	# Se la scelta non ne ha una resta quella dell'incontro, che c'entra sempre.
	var choices: Array = event.get("choices", [])
	var scelta: Dictionary = choices[index] if index >= 0 and index < choices.size() else {}
	righe.append(_illustrazione(scelta if scelta.has("image") else event))

	for line in lines:
		var riga := Ui.label(String(line), Palette.FONT_BODY, Palette.GOLD)
		riga.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		riga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		riga.custom_minimum_size.x = 1
		righe.append(riga)
	righe.append(Ui.spacer(Palette.PAD_SMALL))
	righe.append(Ui.center_row(Ui.button("Avanti", _apri_bottega)))

	var colonna := Ui.vbox(righe, Palette.PAD_SMALL)
	colonna.custom_minimum_size.x = ILLUSTRAZIONE.x
	_event_panel.add_child(Ui.center(Ui.panel(Ui.margin(colonna, Palette.PAD))))
	Audio.sfx("coin")


# --- bottega -------------------------------------------------------------

func _on_buy_card(index: int) -> void:
	if market.buy_card(index, run) == null:
		Events.toast("Oro insufficiente", "bad")
		Audio.sfx("error")
		return
	Audio.sfx("buy")
	_salva()
	_refresh_shop()


func _on_buy_relic(index: int) -> void:
	if index < 0 or index >= market.relic_offers.size():
		return
	if run.gold() < market.relic_price(market.relic_offers[index]):
		Events.toast("Oro insufficiente", "bad")
		Audio.sfx("error")
		return
	var relic := market.buy_relic(index, run)
	if relic.is_empty():
		Audio.sfx("error")
		return
	# Frase neutra rispetto al genere: il participio concordava col nome, e i nomi
	# hanno generi diversi — «Pokedex è tua» era sbagliato già in italiano.
	Events.toast(tr("Hai preso: %s") % tr(String(relic.get("name", "una reliquia"))), "good")
	Audio.sfx("level_up")
	_salva()
	_refresh_shop()


## Gli innesti si comprano in due tempi: prima si sceglie l'innesto, poi la carta
## che deve portarlo. Il secondo click arriva da _on_deck_card_clicked.
func _on_pick_seal(index: int) -> void:
	if index < 0 or index >= market.seal_offers.size():
		return
	var seal: Dictionary = market.seal_offers[index]
	if run.gold() < market.seal_price(seal):
		Events.toast("Oro insufficiente", "bad")
		Audio.sfx("error")
		return
	_pending = Pending.SEAL
	_pending_seal = index
	_overlay = Overlay.DECK
	_refresh_shop()


func _on_arm_remove() -> void:
	if not run.can_remove():
		Events.toast("Il mazzo è già al minimo", "bad")
		Audio.sfx("error")
		return
	if run.gold() < market.remove_price():
		Events.toast("Oro insufficiente", "bad")
		Audio.sfx("error")
		return
	_pending = Pending.REMOVE
	_overlay = Overlay.DECK
	_refresh_shop()


func _on_deck_card_clicked(card: Card) -> void:
	match _pending:
		Pending.REMOVE:
			if market.remove_card(card, run):
				Events.toast(tr("%s via dal mazzo") % tr(card.display_name), "info")
				Audio.sfx("cancel")
			else:
				Audio.sfx("error")
		Pending.SEAL:
			if market.buy_seal(_pending_seal, card, run):
				# Neutra anche questa: «Re di Picche innestata» concordava col
				# nome della carta, che non ha sempre lo stesso genere.
				Events.toast(tr("Innesto messo su %s") % tr(card.display_name), "good")
				Audio.sfx("level_up")
			else:
				Events.toast("Quella carta ha già due innesti", "bad")
				Audio.sfx("error")
		_:
			return

	_pending = Pending.NONE
	_pending_seal = -1
	_overlay = Overlay.NONE
	_salva()
	_refresh_shop()


func _on_reroll() -> void:
	if not market.reroll(run, run.round_number):
		Events.toast("Oro insufficiente", "bad")
		Audio.sfx("error")
		return
	# Non un clic — quello lo suona gia' il bottone: le carte che scorrono via.
	Audio.sfx("whoosh")
	_salva()
	_refresh_shop()


func _toggle_overlay(quale: Overlay) -> void:
	# Un pannello aperto si richiude premendo di nuovo lo stesso bottone.
	_overlay = Overlay.NONE if _overlay == quale else quale
	if _overlay == Overlay.NONE:
		_pending = Pending.NONE
	_refresh_shop()


# --- schermata -----------------------------------------------------------

## Lo sfondo di ogni fase. Il file manca senza far danni: resta il fondo pieno.
const SFONDI := {
	Phase.SHOP: "res://game/art/sfondi/bottega.png",
	# La scheda dell'avversario è già davanti al tavolo: stesso posto della
	# battaglia, così passare da una all'altra non cambia scena.
	Phase.PREVIEW: "res://game/art/sfondi/battaglia.png",
	Phase.BATTLE: "res://game/art/sfondi/battaglia.png",
	# Anche l'incontro ha il suo posto. **Nessuna schermata resta nera**: dietro
	# c'è sempre un luogo, e un dialogo su fondo nero sembra un caricamento
	# rimasto a metà.
	Phase.EVENT: "res://game/art/sfondi/bottega.png",
}

## Quanto buio ci va sopra. Gli sfondi sono illustrazioni piene di dettaglio e
## di luce: senza velo, sopra ci si legge male tanto il testo chiaro quanto
## quello scuro, e le carte bianche spariscono dentro il muro giallo del bar.
const VELO_SFONDO := 0.68


## Il fondo illustrato e il suo velo. Nascono una volta sola e restano dietro a
## tutto: cambia solo la texture, quando cambia la fase.
func _costruisci_sfondo() -> void:
	_sfondo = TextureRect.new()
	_sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sfondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sfondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVERED e non KEEP_ASPECT: l'illustrazione riempie sempre lo schermo, anche
	# a schermo intero su un monitor di proporzioni diverse. Meglio perderne un
	# pezzo ai bordi che ritrovarsi due bande nere.
	_sfondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_sfondo)

	var velo := Ui.background(Hud.INCHIOSTRO)
	velo.color.a = VELO_SFONDO
	add_child(velo)


func _aggiorna_sfondo() -> void:
	_metti_sfondo(String(SFONDI.get(phase, "")))


## Mette quell'immagine dietro a tutto. Percorso vuoto o file mancante: **si
## tiene quella di prima**, non si torna al nero. È la regola che vale per ogni
## schermata, e soprattutto per i dialoghi: un fondo nero dietro a due che
## parlano sembra una scena che non ha finito di caricare.
func _metti_sfondo(percorso: String) -> void:
	if percorso == "" or not ResourceLoader.exists(percorso):
		return
	_sfondo.texture = load(percorso)


func _build_layout() -> void:
	add_child(Ui.background())
	_costruisci_sfondo()
	# Subito, non al primo cambio di fase: l'introduzione parla prima che una
	# schermata esista, e senza questa riga parlerebbe sul nero.
	_aggiorna_sfondo()

	_shop_panel = Ui.vbox([], Palette.PAD_SMALL)
	_battle_panel = Ui.vbox([], Palette.PAD)
	_battle_panel.visible = false
	_event_panel = Ui.vbox([], Palette.PAD)
	_event_panel.visible = false
	_preview_panel = Ui.vbox([], Palette.PAD)
	_preview_panel.visible = false

	# Centrata in verticale: le schermate hanno altezze molto diverse fra loro
	# (la bottega è alta, un incontro no) e appoggiate in cima lasciano mezzo
	# schermo vuoto sotto.
	var colonna := Ui.vbox([
		_shop_panel, _event_panel, _preview_panel, _battle_panel,
	], Palette.PAD_SMALL)
	colonna.alignment = BoxContainer.ALIGNMENT_CENTER

	add_child(Ui.fullscreen(Ui.margin(colonna, Palette.PAD)))

	# Il mazzo e le reliquie stanno **sopra** la schermata, non sotto di lei.
	#
	# Prima erano una riga in più nella colonna della bottega, e la colonna con
	# tutte e due dentro era più alta dello schermo: la parte bassa del mazzo
	# finiva oltre il bordo e non c'era scorrimento che tenesse, perché era la
	# finestrella dello scorrimento a stare fuori. Le carte irraggiungibili erano
	# **le ultime**, cioè proprio quelle appena comprate o appena regalate da una
	# reliquia — le uniche che uno apre il mazzo per andare a vedere.
	_overlay_panel = PanelContainer.new()
	_overlay_panel.add_theme_stylebox_override("panel", ThemeBuilder.box(
		Palette.BG_DEEP, Palette.ACCENT_DIM, Palette.RADIUS, Palette.BORDER_WIDTH
	))
	_overlay_layer = Ui.background(Hud.INCHIOSTRO)
	_overlay_layer.color.a = 0.85
	# Il velo mangia i click: sotto c'è una bottega su cui si continuerebbe a
	# comprare senza vederla.
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.visible = false
	_overlay_layer.add_child(Ui.center(_overlay_panel))
	add_child(_overlay_layer)

	# I gesti stanno sopra il tavolo e sotto tutto ciò che si legge: il riepilogo
	# di fine round, la scheda della carta e i dialoghi li coprono, e va bene
	# così — quando c'è da leggere, un fantasma che passa è solo disturbo.
	_gesti = Gesti.new()
	add_child(_gesti)

	# Il riepilogo di fine round, sopra la battaglia e sotto la scheda delle
	# carte. Il velo non è solo estetico: mangia i click, o si continuerebbe a
	# comprare in una bottega che sta sotto e non si vede.
	_round_panel = Ui.vbox([], Palette.PAD_SMALL)
	# Largo abbastanza da non cambiare forma fra un round vinto e uno perso: le
	# righe sono diverse, e un riquadro che salta a ogni round si nota.
	_round_panel.custom_minimum_size.x = 380
	_round_layer = Ui.background(Hud.INCHIOSTRO)
	_round_layer.color.a = 0.8
	_round_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_round_layer.visible = false
	_round_layer.add_child(Ui.center(Hud.cornice(Ui.margin(_round_panel, Hud.PAD))))
	add_child(_round_layer)

	# Aggiunta per ultima: in un Control i figli si disegnano nell'ordine in cui
	# sono, e la scheda deve stare sopra bottega, battaglia e pannelli a
	# scomparsa. Vuota e invisibile finché il mouse non tocca una carta.
	_detail = CardDetail.new()
	add_child(_detail)

	# Dopo la scheda: quando la storia parla, copre tutto, comprese le carte.
	_dialogo = Dialogo.new()
	_dialogo.finito.connect(_on_dialogo_finito)
	_dialogo.trova_rettangolo = _rettangolo_di
	add_child(_dialogo)


## La bottega della bozza: intestazione, cinque carte in vetrina, e sotto tre
## colonne — reliquie a sinistra, comandi al centro, innesti a destra.
##
## Ogni nodo nasce qui dentro e muore qui dentro. Niente variabili membro: è la
## regola che tiene in piedi tutta la funzione.
func _refresh_shop() -> void:
	_clear(_shop_panel)

	var recipe := run.opponent_for_round()

	# Intestazione: round a sinistra, i due pannelli a richiesta al centro, oro a destra.
	# Le due cose che dicono a che punto è la partita, e vanno lette insieme:
	# quante ne hai vinte, e quanto ti resta per vincere le altre. Prima qui
	# c'era "Round 7/10", che metteva a confronto due numeri diversi — le
	# battaglie giocate e le vittorie che servono.
	#
	# Le vite si accendono di rosso quando ne bastano due sconfitte a chiuderla:
	# è l'informazione che cambia cosa vale la pena comprare.
	var vite_rimaste := maxi(run.lives, 0)
	var in_pericolo := vite_rimaste <= run.life_cost() * 2
	var vite := Ui.hbox([
		Ui.label("%d" % vite_rimaste, Palette.FONT_HEADING,
			Palette.DANGER if in_pericolo else Palette.TEXT),
		Ui.dim(Testo.plurale(vite_rimaste, "vita", "vite")),
	], Palette.PAD_SMALL)

	# Ogni pezzo che il tutorial può accendere passa da `_segna`: è quello che
	# permette a GiGi di parlare del bottone illuminato invece che in astratto.
	var intestazione := Ui.hbox([
		_segna("vittorie", Ui.panel(Ui.margin(Ui.label(tr("Vittorie %d/%d")
			% [run.wins, run.wins_needed()], Palette.FONT_HEADING), Palette.PAD_SMALL))),
		_segna("vite", Ui.panel(Ui.margin(vite, Palette.PAD_SMALL))),
		Ui.spacer(),
		_segna("vedi_mazzo", Ui.button(tr("Vedi mazzo (%d)") % run.deck_size(),
			func() -> void: _toggle_overlay(Overlay.DECK))),
		_segna("vedi_reliquie", Ui.button(tr("Vedi reliquie (%d)") % run.relics.size(),
			func() -> void: _toggle_overlay(Overlay.RELICS))),
		Ui.spacer(),
		_segna("oro", Ui.panel(Ui.margin(Ui.label(tr("%d oro") % run.gold(), Palette.FONT_HEADING,
			Palette.GOLD), Palette.PAD_SMALL))),
	], Palette.PAD_SMALL)

	# La vetrina delle carte, con il prezzo sotto ciascuna.
	var vetrina := Ui.hbox([], Palette.PAD_SMALL)
	vetrina.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in market.card_offers.size():
		var card: Card = market.card_offers[i]
		var view := _carta(card, true, CardView.Mode.SHOP)
		var index := i
		view.clicked.connect(func(_c: Card) -> void: _on_buy_card(index))

		var prezzo := market.card_price(card)
		var etichetta := Ui.label(tr("%d oro") % prezzo, Palette.FONT_BODY,
			Palette.GOLD if prezzo <= run.gold() else Palette.TEXT_MUTED)
		etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vetrina.add_child(Ui.vbox([view, etichetta], 2))

	# Reliquie e innesti: due griglie da due colonne, come nella bozza.
	var reliquie := _segna("reliquie", Ui.grid(2, [], Palette.PAD_SMALL))
	for i in market.relic_offers.size():
		var relic: Dictionary = market.relic_offers[i]
		var index := i
		reliquie.add_child(_bottone_acquisto(
			String(relic.get("name", "?")), String(relic.get("text", "")),
			market.relic_price(relic), func() -> void: _on_buy_relic(index),
			ReliquieArt.per_reliquia(relic)
		))

	var innesti := _segna("innesti", Ui.grid(2, [], Palette.PAD_SMALL))
	for i in market.seal_offers.size():
		var seal: Dictionary = market.seal_offers[i]
		var index := i
		var scelto := _pending == Pending.SEAL and _pending_seal == index
		# Il segno di «scelto» si attacca al nome **già tradotto**: attaccandolo
		# prima, la Label non riconosce più la chiave e il nome resta in italiano.
		innesti.add_child(_bottone_acquisto(
			("▸ " if scelto else "") + tr(String(seal.get("name", "?"))),
			String(seal.get("text", "")),
			market.seal_price(seal), func() -> void: _on_pick_seal(index)
		))

	var prosegui := _segna("prosegui", Ui.button("Prosegui", _prosegui))
	prosegui.custom_minimum_size.y = 48
	var centro := Ui.vbox([
		_segna("rimescola", Ui.button(tr("Rimescola (%d)") % market.reroll_price(), _on_reroll)),
		_segna("butta", Ui.button(tr("Butta una carta (%d)") % market.remove_price(), _on_arm_remove)),
		Ui.spacer(Palette.PAD),
		prosegui,
	], Palette.PAD_SMALL)
	centro.custom_minimum_size.x = LARGHEZZA_CENTRO

	# Il nome dell'avversario va a capo invece di allargare la colonna.
	# È l'unico pezzo della bottega che spingeva: le due griglie laterali sono
	# a larghezza fissa e i bottoni si tagliano da soli (clip_text), ma una
	# Label cresce quanto vuole. Con la lingua finta a +30% questa riga da sola
	# faceva sforare la schermata di 58 px.
	var sfidante := Ui.heading(tr("Ti aspetta %s") % tr(String(recipe.get("name", "qualcuno"))))
	sfidante.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sfidante.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sfidante.custom_minimum_size.x = LARGHEZZA_CENTRO

	var colonne := Ui.hbox([
		Ui.vbox([Ui.center_row(Ui.dim("RELIQUIE")), reliquie], Palette.PAD_SMALL),
		Ui.spacer(),
		Ui.vbox([sfidante, centro], Palette.PAD_SMALL),
		Ui.spacer(),
		Ui.vbox([Ui.center_row(Ui.dim("INNESTI")), innesti], Palette.PAD_SMALL),
	], Palette.PAD)

	# La bottega ha un nome, e il nome è il posto: fra una sfida e l'altra si
	# torna sempre lì, ed è l'unica cosa che non cambia mai in tutta la partita.
	var insegna := Ui.label(NOME_BOTTEGA, Palette.FONT_HEADING, Hud.ORO)
	insegna.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_shop_panel.add_child(intestazione)
	_shop_panel.add_child(Ui.center_row(_segna("insegna", insegna)))
	_shop_panel.add_child(Ui.center_row(Ui.dim(_pending_hint())))
	_shop_panel.add_child(_segna("vetrina", vetrina))
	_shop_panel.add_child(colonne)

	_refresh_overlay()


## Un acquisto: nome e prezzo dentro un bottone solo, spento se non te lo puoi
## permettere. Il testo lungo sta nel tooltip, altrimenti la griglia esplode.
## L'insegna sopra la vetrina. È la stessa a ogni passaggio: la bottega è un
## posto, non una schermata.
const NOME_BOTTEGA := "Bottega Angelini"


## Quanto è largo un bottone della bottega. Due colonne di questi a sinistra, due
## a destra e la colonna dei comandi in mezzo: il conto deve stare dentro i 1152
## px della finestra, e cresce con la larghezza qui sotto.
const LARGHEZZA_ACQUISTO := 196

## La colonna di mezzo della bottega. È un tetto, non un desiderio: le due
## griglie laterali sono fisse, e quello che avanza è tutto quello che c'è.
const LARGHEZZA_CENTRO := 275

# NOTA PER CHI TRADURRA', misurata e non stimata: questa riga in alto —
# «Vittorie x/y · N vite · Vedi mazzo (N) · Vedi reliquie (N) · N oro» — occupa
# 1128 px su 1152, cioè ha il 2% di margine. Con la lingua finta a +30% (F7)
# sfora di 310 px, e due terzi sono i due bottoni «Vedi …».
#
# Fissarne la larghezza NON è il rimedio: in italiano «Vedi reliquie (12)» è
# già più largo di qualunque tetto sensato, e verrebbe troncato prima ancora di
# tradurre. È una decisione di contenuto, non un parametro — etichette più
# corte, o un'icona col numero accanto. Va presa insieme alla prima lingua.


func _bottone_acquisto(nome: String, spiegazione: String, prezzo: int, azione: Callable,
		icona: Texture2D = null) -> Button:
	var bottone := Ui.button("", azione)
	# Il nome per esteso sta nel tooltip, perché sul bottone può non starci: una
	# reliquia si chiama "Tavola delle Sacre Puntate" e in due colonne di bottoni
	# larghi quanto il loro testo la bottega usciva dallo schermo a destra.
	bottone.tooltip_text = tr("%s — %d oro\n\n%s") % [tr(nome), prezzo, tr(spiegazione)]
	bottone.custom_minimum_size = Vector2(LARGHEZZA_ACQUISTO, 38)
	bottone.disabled = prezzo > run.gold()

	# Il testo non sta **dentro** il bottone ma sopra, in una riga: col testo del
	# bottone il nome e il prezzo erano una stringa sola, e i puntini di taglio
	# si mangiavano proprio il prezzo — cioè l'unica cosa che serve a decidere.
	# Qui il nome si accorcia e il prezzo resta, sempre, in fondo a destra.
	var riga := Ui.hbox([], Palette.PAD_SMALL)
	riga.set_anchors_preset(Control.PRESET_FULL_RECT)
	riga.offset_left = Palette.PAD_SMALL
	riga.offset_right = -Palette.PAD_SMALL
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# L'icona, quando c'è: con diciotto reliquie il nome tagliato dai puntini non
	# basta più a riconoscerle, e il disegno si legge prima della parola.
	if icona != null:
		var quadro := TextureRect.new()
		quadro.texture = icona
		quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quadro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		quadro.custom_minimum_size = Vector2(26, 26)
		quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		riga.add_child(quadro)

	var etichetta := Ui.label(nome, Palette.FONT_BODY,
		Palette.TEXT if prezzo <= run.gold() else Palette.TEXT_MUTED)
	etichetta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etichetta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etichetta.clip_text = true
	etichetta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etichetta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riga.add_child(etichetta)

	var costo := Ui.label(str(prezzo), Palette.FONT_BODY,
		Palette.GOLD if prezzo <= run.gold() else Palette.TEXT_MUTED)
	costo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	costo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	costo.custom_minimum_size.x = 22
	costo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riga.add_child(costo)

	bottone.add_child(riga)
	return bottone


## L'icona di una reliquia, o il posto che le spetta. Un riquadro vuoto invece
## di niente: senza, la colonna dei nomi si sposta a seconda di chi ha il disegno
## e chi no, e l'elenco balla.
func _icona_reliquia(relic: Dictionary, misura: int = 48) -> Control:
	var icona := TextureRect.new()
	icona.texture = ReliquieArt.per_reliquia(relic)
	icona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icona.custom_minimum_size = Vector2(misura, misura)
	icona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icona


func _pending_hint() -> String:
	match _pending:
		Pending.REMOVE:
			return "Scegli la carta da buttare"
		Pending.SEAL:
			return "Scegli la carta su cui mettere l'innesto"
		_:
			var in_pila := maxi(run.deck_size() - Cfg.get_int("player.board_size", 5) - run.board_bonus(), 0)
			return tr("%d carte nel mazzo — %d restano in pila dopo il primo giro") \
				% [run.deck_size(), in_pila]


## Il pannello a scomparsa sopra la bottega: o il mazzo, o le reliquie.
## Quanto in alto può arrivare il mazzo aperto prima di doversi far scorrere.
## Quanto schermo può prendersi il mazzo, in verticale. Il resto se lo mangiano
## l'intestazione, il bottone Chiudi e i margini della cornice.
##
## È una **frazione**, non un numero di pixel: 300 fissi bastavano a 648 di
## altezza e sprecavano metà finestra su uno schermo grande, e in una jam la
## finestra la ridimensiona chi passa allo stand.
const QUOTA_SCHERMO_MAZZO := 0.72


func _scorrevole(contenuto: Control) -> ScrollContainer:
	var disponibile := get_viewport_rect().size.y * QUOTA_SCHERMO_MAZZO
	var scorri := ScrollContainer.new()
	scorri.custom_minimum_size.y = minf(contenuto.get_combined_minimum_size().y, disponibile)
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scorri.follow_focus = true
	contenuto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorri.add_child(contenuto)
	return scorri


## Chiude il mazzo e le reliquie. Un punto solo, perché lo stato è in due posti —
## `_overlay` e la visibilità del velo — e tenerli allineati a mano da cinque
## chiamanti diversi è il modo di lasciare un velo nero su tutto lo schermo.
func _chiudi_overlay() -> void:
	_overlay = Overlay.NONE
	if _overlay_layer != null:
		_overlay_layer.visible = false


func _refresh_overlay() -> void:
	_clear(_overlay_panel)
	_overlay_layer.visible = _overlay != Overlay.NONE
	if not _overlay_layer.visible:
		return

	var contenuto: Control
	if _overlay == Overlay.DECK:
		var griglia := Ui.grid(12, [], Palette.PAD_SMALL)
		var cliccabile := _pending != Pending.NONE
		for card in run.collection:
			var view := _carta(card, cliccabile, CardView.Mode.COMPACT)
			if cliccabile:
				view.clicked.connect(_on_deck_card_clicked)
			griglia.add_child(view)
		contenuto = Ui.vbox([
			Ui.hbox([Ui.dim("IL TUO MAZZO"), Ui.spacer(),
				Ui.button("Chiudi", func() -> void: _toggle_overlay(Overlay.DECK))]),
			_scorrevole(griglia),
		], Palette.PAD_SMALL)
	else:
		var righe: Array[Control] = [Ui.hbox([Ui.dim("LE TUE RELIQUIE"), Ui.spacer(),
			Ui.button("Chiudi", func() -> void: _toggle_overlay(Overlay.RELICS))])]
		if run.relics.is_empty():
			righe.append(Ui.dim("Non ne hai ancora. Si comprano qui in bottega, una sola volta ciascuna."))
		for relic in run.relics:
			var descrizione := Ui.dim(String(relic.get("text", "")))
			descrizione.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			descrizione.custom_minimum_size.x = 1
			descrizione.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			righe.append(Ui.hbox([
				_icona_reliquia(relic),
				Ui.vbox([
					Ui.label(String(relic.get("name", "")), Palette.FONT_BODY, Palette.SECONDARY),
					descrizione,
				], 2),
			], Palette.PAD_SMALL))
		contenuto = Ui.vbox(righe, Palette.PAD_SMALL)

	_overlay_panel.add_child(Ui.margin(contenuto, Palette.PAD))


# --- battaglia -----------------------------------------------------------

## Il campo della bozza: barra della vita avversaria in alto, le due file di
## carte una di fronte all'altra, la propria barra in basso. Ai lati il numero
## del round e i due riquadri d'informazioni.
func _build_battle_view() -> void:
	_clear(_battle_panel)
	_views.clear()
	_panels.clear()

	# LA RIGA DI RESOCONTO NON DEVE DECIDERE QUANTO È LARGA LA SCHERMATA.
	#
	# Cambia a ogni attivazione — quaranta volte a battaglia — e passa da
	# «Tu — Due di Coppe: 2 cura» (132 px) a «Il Vecchio Contadino — Re di
	# Bastoni: 4 rallenta · 2 indebolisce · 5 danni · …» (1169 px). Senza
	# vincoli la sua larghezza minima è quella del testo intero, e siccome sta
	# nella colonna centrale di un HBox centrato, allargava tutto il tavolo e
	# lo faceva tornare indietro un secondo dopo: al round 10 il pannello
	# passava da 1128 a 1513 px, 361 dei quali fuori dallo schermo.
	#
	# `clip_text` toglie il testo dal calcolo della misura minima, `EXPAND_FILL`
	# le fa prendere tutta la larghezza che la colonna ha già. Da qui in poi la
	# riga è larga sempre uguale e le frasi lunghe finiscono in «…».
	# Verificabile: tools/misura_stabilita.gd

	var suo := SidePanel.new(opponent)
	var mio := SidePanel.new(player)
	_panels.append(suo)
	_panels.append(mio)

	# Le chiavi servono al tutorial: sono i pezzi che GiGi può illuminare mentre
	# spiega vita, danni, attesa e mazzo.
	var campo := Ui.vbox([
		_segna("vita_sua", suo.barra()),
		_segna("fila_sua", _fila_carte(opponent)),
		_mezzeria(),
		_segna("fila_mia", _fila_carte(player)),
		_segna("vita_mia", mio.barra()),
	], Palette.PAD_SMALL)
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var badge := RoundBadge.new(run.round_number, run.total_rounds())
	var lato_sinistro := Ui.vbox([Ui.spacer(), badge, Ui.spacer(),
		_segna("pila_mia", mio.info())], Palette.PAD_SMALL)
	var lato_destro := Ui.vbox([_segna("pila_sua", suo.info()), Ui.spacer(),
		_riquadro_vite(), Ui.spacer()], Palette.PAD_SMALL)

	_battle_panel.add_child(Ui.hbox([lato_sinistro, campo, lato_destro], Palette.PAD))


## La striscia vuota fra i due schieramenti.
##
## Qui c'era una cronaca della battaglia — una riga a ogni attivazione, quaranta
## a battaglia. È stata tolta per due ragioni indipendenti, e la seconda vale
## più della prima.
##
## La prima: cambiando testo cambiava larghezza, e da dentro la colonna
## centrale di un HBox centrato allargava tutto il tavolo e lo faceva tornare
## indietro un secondo dopo — al round 10 da 1128 a 1513 px. Quello si sarebbe
## corretto (`tools/misura_stabilita.gd` lo misura).
##
## La seconda: **non diceva niente che il tavolo non dicesse meglio**. La carta
## che spara si vede sparare, il numero del colpo esce sulla carta ed è già
## scontato di scudo, catena e resistenze. Leggere non è mai stato più veloce
## che guardare. E il verdetto di fine battaglia lo dice il riepilogo un secondo
## dopo, con la stessa identica frase e più in grande.
##
## Resta lo spazio, che non è vuoto per caso: separa il suo lato dal tuo.
func _mezzeria() -> Control:
	var striscia := Control.new()
	striscia.custom_minimum_size.y = Hud.font().get_height(Palette.FONT_BODY)
	striscia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return striscia


func _riquadro_vite() -> PanelContainer:
	var vite := maxi(run.lives, 0)
	var testo := Ui.label(Testo.plurale(vite, "%d vita", "%d vite") % vite, Palette.FONT_BODY,
		Palette.DANGER if run.lives <= 1 else Palette.TEXT)
	testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pannello := Ui.panel(Ui.margin(testo, Palette.PAD_SMALL))
	pannello.custom_minimum_size.x = SidePanel.LARGHEZZA_INFO
	return pannello


func _fila_carte(side: Side) -> HBoxContainer:
	var row := Ui.hbox([], Palette.PAD_SMALL)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var views: Array[CardView] = []
	for slot in side.board_size:
		var view := _carta(side.board[slot], false, CardView.Mode.SLOT)
		views.append(view)
		row.add_child(_cella(view))
	_views[side] = views
	return row


## Una carta in battaglia non sta nella fila: sta in una **cella**, e la cella
## sta nella fila.
##
## Il motivo è misurato, non teorico: un `Container` riscrive `position` e
## azzera `scale` dei figli a ogni riordino, e a riordinare basta pochissimo —
## una carta vicina che cambia testo, un figlio che compare, e soprattutto F5,
## che riassegna il tema alla radice e fa `queue_sort()` su ogni contenitore
## dell'albero. Un `Control` nudo invece non tocca niente: dentro la cella la
## posizione della carta è nostra, ed è quella che permette alla carta nuova di
## salire al suo posto.
func _cella(view: CardView) -> Control:
	var cella := Control.new()
	cella.custom_minimum_size = CardView.SIZES[CardView.Mode.SLOT]
	# IGNORE sulla cella, non sulla carta: la cella si fa attraversare e la
	# carta sotto continua a ricevere il mouse, che è quello che apre la scheda.
	cella.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	cella.add_child(view)
	return cella


func _refresh_slot(side: Side, slot: int) -> void:
	var views: Array = _views.get(side, [])
	if slot < 0 or slot >= views.size():
		return

	var view: CardView = views[slot]
	# Se la scheda era aperta proprio su questa carta va rifatta: in battaglia lo
	# slot si svuota e ripesca da solo, e il mouse può restare fermo lì sopra per
	# tre carte di fila senza che nessun `mouse_exited` arrivi mai.
	var era_aperta := _detail.mostra_la_carta(view.card)
	view.set_card(side.board[slot])
	# Mentre la precedente se ne va verso il bersaglio, questa sale al suo posto
	# dalla parte del proprio mazzo. Vale anche per il furto e per l'evoluzione,
	# che passano di qui: anche lì lo slot cambia inquilino, e si deve vedere.
	view.entra(_casa(side))
	if not era_aperta:
		return
	if view.card != null:
		_detail.mostra(view.card, view.get_global_rect())
	else:
		_detail.nascondi()


func _clear(node: Node) -> void:
	# La scheda del dettaglio va chiusa **prima**: se resta aperta appoggiata a
	# una carta che sta per essere liberata, mostra la carta di una schermata che
	# non esiste più finché il mouse non passa da qualche altra parte.
	if _detail != null:
		_detail.nascondi()
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- i pezzi di schermata che il tutorial illumina ------------------------
#
# GiGi non spiega concetti: spiega **la cosa che in quel momento è l'unica
# illuminata sullo schermo**. Una battuta con `"evidenzia": "vedi_mazzo"` accende
# il bottone che sta qui sotto con quella chiave, e il velo del dialogo ci fa un
# buco intorno.
#
# Il registro si svuota da solo: le schermate si ricostruiscono di continuo e i
# nodi di prima sono già stati liberati, per questo `_rettangolo_di` controlla
# sempre `is_instance_valid` invece di fidarsi.

var _pezzi := {}


## Registra un pezzo di schermata e lo restituisce, così si può avvolgere la
## riga che lo crea senza spezzarla in due.
func _segna(chiave: String, nodo: Control) -> Control:
	_pezzi[chiave] = nodo
	return nodo


## Dove sta quel pezzo, adesso. Rettangolo vuoto se in questa schermata non c'è:
## il dialogo lo legge come "nessun buco" e tira dritto col velo pieno.
func _rettangolo_di(chiave: String) -> Rect2:
	var nodo: Variant = _pezzi.get(chiave)
	if not (nodo is Control) or not is_instance_valid(nodo):
		return Rect2()
	var control := nodo as Control
	if not control.is_visible_in_tree():
		return Rect2()
	return control.get_global_rect()


# --- la storia -----------------------------------------------------------

## Apre la scena di dialogo agganciata a questo momento, se ce n'è una che non è
## già stata vista. Restituisce **falso se non ha aperto niente**, e allora chi
## chiama tira dritto: è per questo che tutte le chiamate hanno la forma
##
##     if not _apri_dialogo("inizio", _enter_shop):
##         _enter_shop()
##
## Una scena non blocca la partita, la mette in coda: `poi` è quello che succede
## quando l'ultima battuta è stata letta — o quando si preme "Salta".
func _apri_dialogo(quando: String, poi: Callable = Callable()) -> bool:
	if senza_dialoghi:
		return false
	var scena := _scena_di_dialogo(quando)
	if scena.is_empty():
		return false

	# Segnata subito, non alla fine: chi salta la scena l'ha comunque avuta, e
	# chi chiude la finestra a metà non se la ritrova a ogni caricamento.
	run.dialoghi_visti.append(String(scena.get("id", "")))
	_dopo_il_dialogo = poi
	# Una scena può dire dove si svolge. Se non lo dice resta il luogo di prima,
	# che è comunque un luogo: dietro a un dialogo non c'è mai il nero.
	_metti_sfondo(String(scena.get("sfondo", "")))
	_dialogo.mostra(scena)
	return true


## La prima scena di questo momento che non sia già passata.
func _scena_di_dialogo(quando: String) -> Dictionary:
	if quando == "":
		return {}
	for scena in Content.list("dialoghi"):
		if String(scena.get("quando", "")) != quando:
			continue
		if String(scena.get("id", "")) in run.dialoghi_visti:
			continue
		return scena
	return {}


func _on_dialogo_finito() -> void:
	# Si svuota **prima** di chiamare: quello che sta in coda può aprire un'altra
	# scena, e ritrovarsi la vecchia coda addosso la rieseguirebbe.
	# Finita la scena si torna al luogo della fase in corso: una scena che aveva
	# cambiato sfondo non se lo porta dietro nella schermata dopo.
	_aggiorna_sfondo()
	var poi := _dopo_il_dialogo
	_dopo_il_dialogo = Callable()
	if poi.is_valid():
		poi.call()


## Il regalo di fine tutorial è già nel mazzo: lo versa `RunState.finish_round`,
## perché il mazzo deve essere lo stesso anche in una run simulata. Qui si fa
## solo rumore e si apre la Bottega Angelini.
func _festeggia_il_regalo() -> void:
	var quante: int = Content.entry("tutorial", "regalo").get("carte", []).size() \
		if Content.has("tutorial", "regalo") else 0
	if quante > 0:
		Events.toast(Testo.plurale(quante,
			"%d carta di città entra nel mazzo",
			"%d carte di città entrano nel mazzo") % quante, "good")
		Audio.sfx("level_up")
	_enter_shop()


## Il momento agganciato alla battaglia che sta per cominciare: la seconda sfida
## e l'ultima hanno una scena loro.
func _quando_prima_della_battaglia() -> String:
	# La prima sfida vera: il Baro è tornato al tavolo e aspetta.
	if run.wins == 0:
		return "prima_sfida_1"
	if run.wins == run.wins_needed() - 1:
		return "prima_ultima"
	return ""


## Il bottone "Prosegui" della bottega. Non porta dritto alla scheda
## dell'avversario perché fra la bottega e il tavolo può esserci una scena da
## guardare: si arriva al bar, si conosce chi ci aspetta, e poi si gioca.
func _prosegui() -> void:
	if not _apri_dialogo(_quando_prima_della_battaglia(), _mostra_avversario):
		_mostra_avversario()


# --- le carte a schermo --------------------------------------------------

## L'unico posto in cui nasce una `CardView`: qui si aggancia la scheda del
## dettaglio, e agganciandola in un punto solo non ci si può dimenticare di
## farlo in una delle tre schermate che mostrano carte.
func _carta(card: Card, cliccabile: bool, modo: CardView.Mode) -> CardView:
	var view := CardView.new(card, cliccabile, modo)
	view.hovered.connect(_on_card_hovered)
	view.unhovered.connect(_on_card_unhovered)
	return view


func _on_card_hovered(view: CardView) -> void:
	_detail.mostra(view.card, view.get_global_rect())


## Si chiude solo se a uscire è la carta che l'aveva aperta. Fra due carte
## accostate l'`entered` della nuova arriva prima dell'`exited` della vecchia:
## senza questo controllo la scheda appena aperta verrebbe richiusa subito.
func _on_card_unhovered(view: CardView) -> void:
	if _detail.mostra_la_carta(view.card):
		_detail.nascondi()


# --- debug ---------------------------------------------------------------

func _register_debug() -> void:
	Dbg.clear_scene_hooks()
	Dbg.watch("Round", func() -> Variant: return run.round_number)
	Dbg.watch("Oro", func() -> Variant: return run.gold())
	Dbg.watch("Vite", func() -> Variant: return run.lives)
	Dbg.watch("Carte", func() -> Variant: return run.deck_size())
	Dbg.watch("Reliquie", func() -> Variant: return run.relics.size())
	Dbg.watch("Mie in pila", func() -> Variant: return player.pile.remaining() if player != null else 0)

	Dbg.command("gold", func(args: Array) -> void:
		run.earn(int(args[0]) if not args.is_empty() else 10)
		if phase == Phase.SHOP:
			_refresh_shop()
	, "gold [n] — regala oro")

	Dbg.command("give", func(args: Array) -> void:
		if args.is_empty():
			return
		var card := CardLibrary.build(args[0])
		if card == null:
			Dbg.log_line("carta sconosciuta: %s (es. picche_c7)" % args[0])
			return
		run.add_card(card)
		if phase == Phase.SHOP:
			_refresh_shop()
	, "give <seme_valore> — aggiunge una carta al mazzo")

	Dbg.command("skip", func(_args: Array) -> void:
		if duel != null and not duel.is_over:
			duel.simulate_to_end()
	, "skip — risolve subito la battaglia")

	Dbg.command("speed", func(args: Array) -> void:
		if duel != null and not args.is_empty():
			duel.speed_up(float(args[0]))
	, "speed <n> — cambia la velocità della simulazione")
