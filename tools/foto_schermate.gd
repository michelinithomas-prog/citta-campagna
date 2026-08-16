extends SceneTree
## Fotografa le schermate di gioco una dopo l'altra — bottega, mazzo, scheda di
## una carta, battaglia, incontro — per confrontarle con le bozze di layout senza
## doverci giocare.
##
##   godot --path templates/cittacampagna \
##         --script res://tools/foto_schermate.gd -- <cartella> [seed]

var play: Node
var _frames := 0
var _passo := 0
var _dir := "/tmp"
var _in_attesa := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_dir = args[0]
	root.get_node("Rng").new_run(int(args[1]) if args.size() >= 2 else 4242)

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
	if _in_attesa != "" or _frames % 40 != 0:
		return false

	_passo += 1
	match _passo:
		1:
			_scatta("bottega")
		2:
			play.run.earn(200)
			play._toggle_overlay(play.Overlay.DECK)
			_scatta("bottega-mazzo")
		3:
			# La scheda che si apre passando il mouse su una carta. Non si può
			# simulare l'hover da qui: si chiama direttamente chi lo ascolta,
			# che è poi tutto quello che l'hover fa.
			play._on_card_hovered(_prima_carta(play))
			_scatta("bottega-scheda")
		4:
			play._toggle_overlay(play.Overlay.DECK)
			play._start_battle()
			_scatta("battaglia")
		5:
			var event: Dictionary = root.get_node("Content").entry("events", "fiera")
			play._show_event(event)
			_scatta("incontro")
		6:
			# L'esito di una scelta: ha un disegno suo quando la scelta se lo
			# porta dietro. Qui la seconda dello "scelta difficile" — la prima
			# chiude la partita, e chiuderebbe anche questa sessione di foto.
			var scelta: Dictionary = root.get_node("Content").entry("events", "scelta")
			play._show_event(scelta)
			play._on_event_choice(scelta, 1)
			_scatta("incontro-esito")
		7:
			# Il fumetto. Si apre a mano scavalcando `senza_dialoghi`, e si salta
			# alla seconda battuta: la prima è una didascalia, e quello che qui
			# interessa vedere è un volto con la sua targa.
			var scena: Dictionary = root.get_node("Content").entry("dialoghi", "inizio")
			play._metti_sfondo(String(scena.get("sfondo", "")))
			play._dialogo.mostra(scena)
			play._dialogo._avanza()
			play._dialogo._testo.visible_characters = -1
			_scatta("dialogo")
		8:
			# Il tutorial mentre indica un pezzo di bottega: si torna in bottega,
			# si apre la lezione e si scorre fino alla prima battuta che accende
			# qualcosa. È quella la cosa da guardare in questa foto.
			play._apri_bottega()
			var lezione: Dictionary = root.get_node("Content").entry("dialoghi", "tutorial_bottega")
			play._dialogo.mostra(lezione)
			for i in 40:
				if String(play._dialogo._battute[play._dialogo._indice].get("evidenzia", "")) != "":
					break
				play._dialogo._avanza()
			play._dialogo._testo.visible_characters = -1
			_scatta("tutorial-evidenzia")
		9:
			# La scheda dell'avversario alla prima sfida: i mazzi non ancora
			# presentati devono comparire come "???".
			play._dialogo.chiudi()
			play._mostra_avversario()
			_scatta("avversario")
		_:
			print("fatte")
			quit(0)
			return true
	return false


## La prima carta a schermo, cercata frugando nell'albero: la vista del mazzo si
## ricostruisce da capo a ogni apertura, e un riferimento preso prima sarebbe già
## morto.
##
## Si riconosce dal percorso del suo script e **non** con `is CardView`, per la
## stessa ragione di `repro_bottega.gd`: nominare la classe qui obbligherebbe
## Godot a compilare `card_view.gd` insieme a questo file, e quello usa gli
## autoload — che quando il MainLoop viene compilato non esistono ancora. Il
## risultato non è un errore secco ma una partita senza carte, che sembra un bug
## del gioco.
func _prima_carta(node: Node) -> Node:
	for child in node.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with("card_view.gd") \
				and child.card != null:
			return child
		var trovata := _prima_carta(child)
		if trovata != null:
			return trovata
	return null


func _scatta(nome: String) -> void:
	_in_attesa = nome
	RenderingServer.frame_post_draw.connect(_salva, CONNECT_ONE_SHOT)


func _salva() -> void:
	var path := "%s/%s.png" % [_dir, _in_attesa]
	root.get_texture().get_image().save_png(path)
	print("scritto: %s" % path)
	_in_attesa = ""
