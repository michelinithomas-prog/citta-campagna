extends SceneTree
## Riproduce il finale di partita fuori dalla finestra di gioco.
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/repro_finale.gd -- <round|last> <deckout|hp>
##
## Pilota play.tscn: porta la run al round scelto, avvia la battaglia e forza
## l'esito voluto, poi guarda cosa succede dopo — bottega, schermata finale, o
## niente.

var play: Node
var _frames := 0
var _forzato := false
var _riportato := false
var _proseguito := false
var _round_arg := "last"
var _modo := "deckout"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_round_arg = args[0]
	if args.size() >= 2:
		_modo = args[1]

	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	# Questo strumento punta a una schermata precisa: i dialoghi li salta.
	# L'introduzione da sola sono centoventi battute, e non è quello che
	# sta misurando.
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play

	# Gli autoload non sono ancora simboli globali quando questo script viene
	# compilato (è lui il MainLoop): si prendono dal root.
	var events_bus := root.get_node("Events")
	var router := root.get_node("Router")

	events_bus.run_ended.connect(func(won: bool, stats: Dictionary) -> void:
		print("[ESITO] run_ended  won=%s  stats=%s" % [won, stats])
	)
	router.scene_changed.connect(func(key: String) -> void:
		print("[SCENA] cambio scena -> %s" % key)
		quit(0)
	)


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 5:
		# **Le vittorie, non i round.** È il conteggio delle vittorie a chiudere la
		# partita: portare avanti solo `round_number` lasciava la run a metà, e
		# questo strumento gridava al softlock per un finale che non era mai stato
		# messo nelle condizioni di arrivare.
		var vittorie: int = play.run.wins_needed() - 1 if _round_arg == "last" \
			else maxi(int(_round_arg) - 1, 0)
		play.run.wins = vittorie
		play.run.round_number = vittorie + 1
		print("[SETUP] vittorie %d di %d, fase=%d" % [
			play.run.wins, play.run.wins_needed(), play.phase])
		play._start_battle()
		print("[SETUP] battaglia avviata, fase=%d" % play.phase)

	if _frames == 12 and not _forzato:
		_forzato = true
		match _modo:
			"deckout":
				play.opponent.pile.draw_pile.clear()
				print("[FORZA] pila avversario svuotata")
			"deckout_mio":
				play.player.pile.draw_pile.clear()
				print("[FORZA] pila mia svuotata: devo perdere per esaurimento")
			"pareggio":
				play.player.pile.draw_pile.clear()
				play.opponent.pile.draw_pile.clear()
				print("[FORZA] pile svuotate da tutte e due le parti")
			"hp_mio":
				play.player.take_damage(9999)
				print("[FORZA] steso io (hp %d)" % play.player.hp)
			_:
				play.opponent.take_damage(9999)
				print("[FORZA] avversario steso (hp %d)" % play.opponent.hp)

	if play.duel != null and play.duel.is_over and not _riportato:
		_riportato = true
		print("[DUELLO] finito  won=%s  reason=%s  frame=%d" % [play.duel.won, play.duel.reason, _frames])

	# Il riepilogo di fine round aspetta un click prima di lasciar passare alla
	# schermata finale. Senza premerlo questo strumento griderebbe al softlock
	# per una schermata che sta funzionando come deve.
	if not _proseguito and play._round_layer.visible:
		_proseguito = true
		var avanti := _primo_bottone(play._round_layer)
		print("[RIEPILOGO] fine round a schermo: premo \"%s\"" % [avanti.text if avanti != null else "?"])
		if avanti != null:
			avanti.pressed.emit()

	# Stato ogni secondo: se `elapsed` non cresce il tempo di gioco è fermo, e
	# allora il banco di prova è rotto, non il gioco.
	if _frames % 400 == 0 and play.duel != null:
		print("[STATO] frame %d  fase=%d  simulati=%.2fs  attivazioni=%d  pila_mia=%d  pila_sua=%d  finito=%s" % [
			_frames, play.phase, play.duel.elapsed, play.duel.activations,
			play.player.pile.remaining(), play.opponent.pile.remaining(), play.duel.is_over
		])

	# Perdere un round NON chiude la partita: si perdono delle vite e si ritrova
	# davanti lo stesso avversario. Aspettare `run_ended` anche in quel caso
	# faceva gridare al softlock una schermata che stava funzionando come deve —
	# e una guardia che grida al lupo è peggio di nessuna guardia.
	if _proseguito and play.phase != Phase_BATTLE and run_viva():
		print("[RIPRESA] la run continua: round %d, %d vite, fase %s" % [
			play.run.round_number, play.run.lives, _nome_fase(play.phase)])
		print("           è il comportamento giusto — perdere un round costa vite,")
		print("           non la partita: si rigioca lo stesso avversario.")
		quit(0)

	if _frames > 4000:
		print("[SOFTLOCK] 4000 frame dopo l'avvio e non è successo niente.")
		print("           riepilogo_a_schermo=%s" % play._round_layer.visible)
		print("           fase=%s  vite=%d  duello_finito=%s" % [
			_nome_fase(play.phase), play.run.lives,
			play.duel.is_over if play.duel != null else "nessun duello"
		])
		quit(1)

	return false


## Phase.BATTLE, senza poter nominare l'enum di play.gd da qui.
const Phase_BATTLE := 3


func _nome_fase(fase: int) -> String:
	return ["incontro", "bottega", "anteprima", "battaglia"][clampi(fase, 0, 3)]


## La run è ancora in piedi: ha vite e non ha ancora vinto.
func run_viva() -> bool:
	return play.run != null and play.run.lives > 0 and play.run.wins < play.run.wins_needed()


func _primo_bottone(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var trovato := _primo_bottone(child)
		if trovato != null:
			return trovato
	return null
