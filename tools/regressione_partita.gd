extends SceneTree
## Gioca una partita intera da solo e si accorge se il gioco si pianta.
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/regressione_partita.gd -- [round_da_raggiungere] [seed]
##
## Preme "Combatti", risolve la battaglia, sceglie la prima opzione agli
## incontri, e va avanti. Se resta fermo nella stessa fase troppo a lungo,
## dichiara il blocco e esce con codice 1.
##
## Serve perché il softlock non si vede in una battaglia sola: nasce quando la
## schermata di battaglia viene ricostruita per la seconda volta.

const FERMO_MAX := 900  ## frame senza avanzamenti prima di gridare al blocco

var play: Node
var _frames := 0
var _fermo := 0
var _round_visti := {}
var _obiettivo := 3
var _seed := 4242
var _ultimo_stato := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_obiettivo = maxi(int(args[0]), 2)
	if args.size() >= 2:
		_seed = int(args[1])

	root.get_node("Rng").new_run(_seed)

	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	root.add_child(play)
	current_scene = play

	root.get_node("Router").scene_changed.connect(func(key: String) -> void:
		print("[SCENA] -> %s al round %d" % [key, play.run.round_number])
		if key == "game_over":
			_verdetto()
	)
	print("[AVVIO] seed %d, obiettivo: arrivare al round %d" % [_seed, _obiettivo])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false

	var stato := "%d/%d" % [play.phase, play.run.round_number]
	if stato != _ultimo_stato:
		_ultimo_stato = stato
		_fermo = 0
		_round_visti[play.run.round_number] = true
		print("[STATO] round %d, fase %s" % [play.run.round_number, _nome_fase()])
	else:
		_fermo += 1

	if play.run.round_number >= _obiettivo and play.phase == play.Phase.SHOP:
		print("[OK] arrivato al round %d senza piantarsi" % play.run.round_number)
		quit(0)
		return true

	_gioca()

	if _fermo > FERMO_MAX:
		print("[BLOCCO] fermo da %d frame nella stessa schermata." % _fermo)
		print("         round=%d  fase=%s  duello_finito=%s" % [
			play.run.round_number,
			_nome_fase(),
			play.duel.is_over if play.duel != null else "nessun duello",
		])
		print("         round giocati: %s" % [_round_visti.keys()])
		quit(1)
		return true

	return false


## Il giocatore finto: combatte appena può e non sta a pensarci troppo.
##
## Agisce a intervalli, non una volta sola: la schermata di un incontro cambia
## contenuto senza cambiare fase (scelta → esito → Avanti), e un bot che preme
## un colpo solo resterebbe lì a guardare l'esito per sempre.
## Il nome della fase corrente, preso dall'enum di play.gd. Scriverne la lista a
## mano significa che la prima fase aggiunta manda l'indice fuori dall'array — ed
## è successo il giorno in cui è arrivata la scheda dell'avversario.
func _nome_fase() -> String:
	for nome in play.Phase:
		if play.Phase[nome] == play.phase:
			return String(nome)
	return "?"


func _gioca() -> void:
	if _fermo % 60 != 30:
		return

	# La storia parla sopra tutto e aspetta un clic a ogni riga. Questo strumento
	# **non** la salta col flag `senza_dialoghi`: la chiude come farebbe il
	# giocatore, così se un giorno una scena non si chiude più il blocco si vede
	# qui e non davanti al pubblico.
	if play._dialogo.visible:
		play._dialogo.chiudi()
		return

	match play.phase:
		play.Phase.SHOP:
			play._mostra_avversario()
		play.Phase.PREVIEW:
			# Il primo bottone della scheda è "Combatti"; il secondo torna
			# indietro, e un giocatore finto che ci ripensasse non finirebbe mai.
			var combatti := _primo_bottone(play._preview_panel)
			if combatti != null:
				combatti.pressed.emit()
		play.Phase.BATTLE:
			# Fra la fine del duello e la bottega c'è il riepilogo del round, e
			# quello aspetta un click: il giocatore finto glielo dà.
			if play._round_layer.visible:
				var avanti := _primo_bottone(play._round_layer)
				if avanti != null:
					avanti.pressed.emit()
			elif play.duel != null and not play.duel.is_over:
				play.duel.simulate_to_end()
		play.Phase.EVENT:
			# Preme il primo bottone che trova: o una scelta, o "Avanti".
			var bottone := _primo_bottone(play._event_panel)
			if bottone != null:
				bottone.pressed.emit()


func _primo_bottone(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var trovato := _primo_bottone(child)
		if trovato != null:
			return trovato
	return null


## Perdere non è un fallimento: questo strumento cerca i BLOCCHI, non giudica
## quanto è bravo il giocatore finto. Se la partita è arrivata a una schermata
## finale ha funzionato, che sia una vittoria o una sconfitta. Un allarme che
## suona quando non deve viene ignorato anche quando deve.
func _verdetto() -> void:
	print("[FINE] la run si è chiusa regolarmente al round %d (%s)" % [
		play.run.round_number, "vinta" if play.run.victory else "persa"
	])
	quit(0)
