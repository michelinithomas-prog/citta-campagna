extends SceneTree
## Fotografa le quattro linee dei gaiofanamon, una riga per seme, coi loro
## disegni e la scheda aperta su un cucciolo.
##
## Serve a una cosa che nessun test può fare: **guardarle**. Che `CarteArt` trovi
## un file lo dice `gaiofanamon_test`; che quel file sia la creatura giusta, e
## non quella della linea accanto, lo dice solo l'occhio.
##
##   godot --path templates/cittacampagna \
##         --script res://tools/foto_gaiofanamon.gd -- <cartella>
##
## Nota di cucina: le classi si prendono con `load()` e si tengono in variabili
## senza tipo. Nominarle direttamente (`CardLibrary`, `Palette`) le farebbe
## compilare **prima** che gli autoload esistano, e il tutto si pianta su
## "Identifier not found: Content". È lo stesso trucco di `diagnosi_economia.gd`.

const LINEE := [
	["acqua", ["g1", "g2", "g3"]],
	["fuoco", ["g1", "g2", "g3"]],
	["erba", ["g1", "g2", "g3"]],
	["elettro", ["g1", "g2"]],
	["antigh", ["a0"]],
	["germoglio", ["s1"]],
]

var _frames := 0
var _dir := "/tmp"
var _pronto := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_dir = args[0]


func _monta() -> void:
	# Sei righe di carte non stanno nella finestra di gioco: qui si fotografa un
	# catalogo, non una schermata.
	DisplayServer.window_set_size(Vector2i(1152, 1180))

	var lib: Object = load("res://game/logic/card_library.gd")
	var vista_cls: Object = load("res://game/ui/card_view.gd")
	var scheda_cls: Object = load("res://game/ui/card_detail.gd")
	var pal: Object = load("res://core/ui/palette.gd")

	var sfondo := ColorRect.new()
	sfondo.color = pal.BG_DEEP
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(sfondo)

	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", pal.PAD)
	colonna.position = Vector2(pal.PAD, pal.PAD)

	for linea in LINEE:
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", pal.PAD)

		var nome := Label.new()
		nome.text = String(linea[0]).to_upper()
		nome.custom_minimum_size.x = 100
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		riga.add_child(nome)

		for rank in linea[1]:
			var card: Object = lib.build("%s_%s" % [linea[0], rank])
			if card != null:
				riga.add_child(vista_cls.new(card, false, 1))  # Mode.SHOP
		colonna.add_child(riga)

	root.add_child(colonna)

	# La scheda di un cucciolo, aperta: è lì che si legge la crescita.
	var scheda: Control = scheda_cls.new()
	root.add_child(scheda)
	scheda.mostra(lib.build("acqua_g1"), Rect2(680, 60, 120, 165))


func _process(_delta: float) -> bool:
	if not _pronto:
		_monta()
		_pronto = true
		return false

	_frames += 1
	if _frames < 20:
		return false

	var percorso := "%s/gaiofanamon.png" % _dir
	root.get_texture().get_image().save_png(percorso)
	print("scritto: ", percorso)
	return true
