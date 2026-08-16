extends SceneTree
## Apre una scena, aspetta qualche frame e salva un PNG. Serve a guardare il
## gioco senza doverlo giocare — utile quando a scrivere il codice è un agente.
##
##   godot --path templates/deckbuilder \
##         --script res://core/tools/screenshot.gd -- res://game/play.tscn /tmp/out.png 40
##
## NON funziona con --headless: lì non c'è nulla da disegnare. La finestra si
## apre per un istante e si chiude da sola.

var _scene_path := ""
var _output_path := ""
var _target_frame := 30
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: --script res://core/tools/screenshot.gd -- <scena.tscn> <output.png> [frames]")
		quit(2)
		return

	_scene_path = args[0]
	_output_path = args[1]
	if args.size() >= 3:
		_target_frame = maxi(int(args[2]), 1)

	if DisplayServer.get_name() == "headless":
		push_error("screenshot.gd richiede una finestra vera: togli --headless")
		quit(2)
		return

	var packed: PackedScene = load(_scene_path)
	if packed == null:
		push_error("scena non caricabile: %s" % _scene_path)
		quit(2)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == _target_frame:
		# L'immagine è disponibile solo a disegno concluso.
		RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)
	return false


func _capture() -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(_output_path)
	if error != OK:
		push_error("impossibile salvare %s (errore %d)" % [_output_path, error])
		quit(1)
		return
	print("screenshot salvato: %s" % _output_path)
	quit(0)
