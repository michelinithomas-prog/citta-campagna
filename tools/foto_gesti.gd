extends SceneTree
## Fotografa una battaglia vera **fotogramma per fotogramma**, a partire dalla
## prima carta che spara. Serve a guardare le animazioni: una schermata sola non
## dice niente di un gesto che dura quattordici frame.
##
##   godot --path templates/cittacampagna --script res://tools/foto_gesti.gd \
##         -- <round> <quanti_frame> <cartella> [seed] [velocita]
##
##   godot --path templates/cittacampagna --script res://tools/foto_gesti.gd \
##         -- 3 90 /tmp/gesti 4242 1
##
## Poi, per vederle in movimento:
##
##   ffmpeg -framerate 60 -i /tmp/gesti/f%03d.png -vf "fps=30" /tmp/gesti.gif
##
## Niente dialoghi (`senza_dialoghi`): l'introduzione da sola sono centoventi
## battute, e con un dialogo aperto `play.gd::_process` congela il tavolo —
## resterebbero fotografati novanta frame di niente.

var play: Node
var _frames := 0
var _scatti := 0
var _partiti := false

var _round_arg := 3
var _quanti := 90
var _cartella := "/tmp/gesti"
var _seed := 4242
var _velocita := 1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_round_arg = maxi(int(args[0]), 1)
	if args.size() >= 2:
		_quanti = clampi(int(args[1]), 1, 600)
	if args.size() >= 3:
		_cartella = args[2]
	if args.size() >= 4:
		_seed = int(args[3])
	if args.size() >= 5:
		_velocita = maxf(float(args[4]), 0.1)

	DirAccess.make_dir_recursive_absolute(_cartella)
	root.get_node("Rng").new_run(_seed)

	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play
	RenderingServer.frame_post_draw.connect(_scatta)


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 5:
		play.run.round_number = _round_arg
		play._start_battle()
		# La velocità si impone al duello appena creato, **non** scrivendo
		# `options.battle_speed`: quella è un'impostazione dell'utente, sta in
		# `user://save.json`, e uno strumento che se la trova comoda gliela
		# cambierebbe per sempre senza dirglielo.
		play.duel.speed_up(_velocita)
		# Si comincia a scattare alla prima carta che parte: prima c'è solo un
		# tavolo fermo, e novanta foto di un tavolo fermo non servono a nessuno.
		# Parametri senza tipo di proposito: annotare `Side` o `Card` qui
		# costringe Godot a compilare `game/logic/` nel momento in cui carica
		# questo file, cioè **prima** che gli autoload esistano, e la
		# compilazione fallisce su `Cfg` e `Content`. Vale per tutti gli
		# strumenti lanciati con `--script`.
		play.duel.card_activated.connect(func(_s, _i, _c) -> void:
			_partiti = true
		)
		return false

	if _partiti and _scatti >= _quanti:
		print("[FOTO] %d fotogrammi in %s" % [_scatti, _cartella])
		quit(0)
		return true

	if _frames > 3000:
		print("[FINE CORSA] nessuna carta ha sparato")
		quit(1)
	return false


## Lo scatto va agganciato a `frame_post_draw` e non fatto dentro `_process`:
## `get_texture().get_image()` letta prima che il frame sia stato disegnato
## restituisce quello di prima, e una raffica di fotogrammi così è un fermo
## immagine ripetuto novanta volte. Ci è già cascato uno strumento.
func _scatta() -> void:
	if not _partiti or _scatti >= _quanti:
		return
	root.get_texture().get_image().save_png("%s/f%03d.png" % [_cartella, _scatti])
	_scatti += 1
