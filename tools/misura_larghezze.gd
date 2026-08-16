extends SceneTree
## Misura quanto è larga davvero ogni schermata e la confronta col viewport.
##
##   godot --path templates/cittacampagna \
##         --script res://tools/misura_larghezze.gd -- [larghezza] [altezza]
##
## Serve quando qualcosa "esce dallo schermo": dice quale riga sfora e di quanto,
## invece di lasciare indovinare. Le dimensioni si leggono dopo che il layout si
## è assestato, non subito: i contenitori di Godot calcolano le misure in
## differita e un minimo letto troppo presto è sempre zero.

var play: Node
var _frames := 0
var _fase := 0
var _viewport := Vector2i(1152, 648)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		_viewport = Vector2i(int(args[0]), int(args[1]))
		DisplayServer.window_set_size(_viewport)

	root.get_node("Rng").new_run(4242)
	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	# Questo strumento punta a una schermata precisa: i dialoghi li salta.
	# L'introduzione da sola sono centoventi battute, e non è quello che
	# sta misurando.
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 30 != 0:
		return false

	_fase += 1
	match _fase:
		1:
			print("viewport logico: %s" % root.get_visible_rect().size)
			_misura("BOTTEGA", play._shop_panel)
		2:
			play.run.earn(300)
			play._toggle_overlay(play.Overlay.DECK)
			_misura("BOTTEGA + mazzo aperto", play._overlay_panel)
		3:
			play._toggle_overlay(play.Overlay.DECK)
			play._start_battle()
			_misura("BATTAGLIA", play._battle_panel)
		4:
			play._show_event(root.get_node("Content").entry("events", "fiera"))
			_misura("INCONTRO", play._event_panel)
		_:
			quit(0)
			return true
	return false


## Stampa la larghezza del pannello e delle sue righe, segnalando chi sfora.
func _misura(nome: String, pannello: Control) -> void:
	var larghezza_utile: float = root.get_visible_rect().size.x
	print("\n=== %s ===" % nome)
	print("  pannello: %.0f px su %.0f disponibili%s" % [
		pannello.size.x, larghezza_utile,
		"   ← SFORA di %.0f" % (pannello.size.x - larghezza_utile) if pannello.size.x > larghezza_utile else ""
	])
	_righe(pannello, larghezza_utile, 1)


func _righe(nodo: Node, limite: float, livello: int) -> void:
	for figlio in nodo.get_children():
		if not figlio is Control:
			continue
		var c := figlio as Control
		var sfora := c.size.x > limite + 0.5
		if sfora or livello < 2:
			print("  %s%s: %.0f × %.0f%s" % [
				"  ".repeat(livello), c.get_class(), c.size.x, c.size.y,
				"   ← SFORA di %.0f" % (c.size.x - limite) if sfora else ""
			])
		if livello < 3:
			_righe(c, limite, livello + 1)
