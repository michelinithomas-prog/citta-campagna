extends SceneTree
## Come sopra, ma con gli occhi: forza un finale e fotografa la schermata che
## resta, tot frame dopo che il duello si è chiuso.
##
##   godot --path templates/cittacampagna --script res://tools/repro_visivo.gd \
##         -- <round> <deckout|hp> <output.png> [frame_dopo_la_fine]

var play: Node
var _frames := 0
var _fine_frame := -1
var _round_arg := "3"
var _modo := "deckout"
var _output := "/tmp/finale.png"
var _dopo := 240


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_round_arg = args[0]
	if args.size() >= 2:
		_modo = args[1]
	if args.size() >= 3:
		_output = args[2]
	if args.size() >= 4:
		_dopo = maxi(int(args[3]), 1)

	# Seed fisso: senza, ogni esecuzione racconta una partita diversa e non si
	# capisce più se una differenza è il bug o il caso.
	root.get_node("Rng").new_run(4242)

	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	# Questo strumento punta a una schermata precisa: i dialoghi li salta.
	# L'introduzione da sola sono centoventi battute, e non è quello che
	# sta misurando.
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play

	root.get_node("Router").scene_changed.connect(func(key: String) -> void:
		print("[SCENA] -> %s (frame %d)" % [key, _frames])
	)


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 5:
		play.run.round_number = play.run.total_rounds() if _round_arg == "last" else int(_round_arg)
		play._start_battle()

	if _frames == 12:
		if _modo == "deckout":
			play.opponent.pile.draw_pile.clear()
		else:
			play.opponent.take_damage(9999)

	if _fine_frame < 0 and play.duel != null and play.duel.is_over:
		_fine_frame = _frames
		print("[DUELLO] won=%s reason=%s frame=%d" % [play.duel.won, play.duel.reason, _frames])

	if _fine_frame > 0 and _frames == _fine_frame + _dopo:
		print("[FOTO] fase=%d (0=EVENT 1=SHOP 2=BATTLE)" % play.phase)
		print("       shop_visibile=%s  evento_visibile=%s  battaglia_visibile=%s  riepilogo=%s" % [
			play._shop_panel.visible, play._event_panel.visible, play._battle_panel.visible,
			play._round_layer.visible
		])
		RenderingServer.frame_post_draw.connect(_scatta, CONNECT_ONE_SHOT)

	if _frames > 4000:
		print("[FINE CORSA] il duello non si è mai chiuso")
		quit(1)

	return false


func _scatta() -> void:
	var image := root.get_texture().get_image()
	image.save_png(_output)
	print("[FOTO] salvata: %s" % _output)
	quit(0)
