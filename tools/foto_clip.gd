extends SceneTree
## Registra una **sequenza** di gioco come clip animata, per una presentazione,
## una pagina di itch.io o un post.
##
## `foto_gesti.gd` fotografa la battaglia fotogramma per fotogramma per
## guardarsela al rallentatore; `foto_schermate.gd` fa scatti singoli. Qui in
## mezzo mancava lo strumento che **pilota** una schermata e ne registra il
## movimento **in tempo reale**, così com'è giocando.
##
##   godot --path templates/cittacampagna --fixed-fps 60 \
##         --script res://tools/foto_clip.gd -- <scena> <cartella> [seed] [scatti]
##
##   godot --path templates/cittacampagna --fixed-fps 60 \
##         --script res://tools/foto_clip.gd -- bottega /tmp/clip-bottega 4242 180
##
## Le scene: `battaglia` · `bottega` · `carte` · `incontro` · `dialogo`.
##
## Poi, per farne una clip (WebP animato pesa un decimo della GIF e in un `<img>`
## si comporta uguale):
##
##   ffmpeg -framerate 20 -i /tmp/clip-bottega/f%03d.png \
##          -vf "scale=576:-1:flags=neighbor" -loop 0 -q:v 72 bottega.webp
##
## ## Il tempo, che è tutto il problema
##
## Salvare un PNG da 1152×648 costa due decimi di secondo. Godot non rallenta per
## aspettarlo: **continua a far girare la simulazione e salta i disegni**, e a
## fotografare quello che passa si ottiene una clip in cui il gioco corre venti
## volte più veloce di com'è. La prima versione di questo strumento comprava una
## carta in dieci fotogrammi.
##
## Quindi il tempo se lo governa lo strumento:
##
## - **`--fixed-fps 60` è obbligatorio.** Sgancia il `delta` dall'orologio vero:
##   ogni iterazione vale esattamente 1/60 di secondo di gioco, quanto ci metta
##   davvero non conta.
## - il disegno **si chiede**, con `RenderingServer.force_draw()`, una iterazione
##   ogni `PASSO`. Con `PASSO = 3` esce un fotogramma ogni 3/60 di secondo: la
##   clip a 20 fps scorre alla velocità vera del gioco.
##
## Da qui la regola per scrivere un copione: **i numeri sono sessantesimi di
## secondo**. `90` vuol dire "un secondo e mezzo dopo l'inizio".
##
## ## Altre note di cucina, pagate dagli strumenti che c'erano già
##
## - **niente annotazioni di tipo** con le classi di `game/`: costringerebbero
##   Godot a compilarle mentre carica questo file, cioè prima che gli autoload
##   esistano, e si pianta su "Identifier not found: Content";
## - le carte si costruiscono al primo `_process` e non in `_initialize`: lì
##   `Content` non ha ancora letto i JSON e tornerebbero tutte nulle;
## - la bottega passa da `RunState.save()`. Il salvataggio vero si mette da parte
##   prima e si rimette a posto alla fine: registrare una clip non deve
##   cancellare la partita di chi sta giocando;
## - **va lanciato in primo piano.** In background la finestra non disegna, la
##   simulazione non parte e la registrazione resta vuota senza dirlo.

## Un disegno ogni tre iterazioni: 20 fotogrammi al secondo, che è la velocità
## vera del gioco una volta rimontati a 20 fps.
const PASSO := 3

## Le quattro carte del confronto città/campagna, una per mazzo: una Picche
## piccola e svelta, un Re di Denari lento e grosso, un Cinque di One e un
## cucciolo. Sono l'illustrazione della regola, non un campione a caso.
const CARTE := [
	["poker — città", "picche_c3"],
	["briscola — campagna", "denari_r10"],
	["one", "rosso_o5"],
	["gaiofanamon", "acqua_g1"],
]

const SALVATAGGIO := "user://save.json"
const MESSO_DA_PARTE := "user://save.json.clip"

var play: Node
var _scena := "bottega"
var _dir := "/tmp/clip"
var _seed := 4242
var _quanti := 180

var _frames := 0
var _scatti := 0
var _registra := false
var _spostato := false

## Le carte del catalogo e la scheda che ci gira sopra: solo la scena `carte`.
var _catalogo: Array = []
var _scheda: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_scena = args[0]
	if args.size() >= 2:
		_dir = args[1]
	if args.size() >= 3:
		_seed = int(args[2])
	if args.size() >= 4:
		_quanti = clampi(int(args[3]), 1, 900)

	DirAccess.make_dir_recursive_absolute(_dir)
	_metti_da_parte_il_salvataggio()
	root.get_node("Rng").new_run(_seed)

	# Il catalogo si monta al primo `_process`; la scena di gioco invece si può
	# istanziare subito, il suo `_ready` arriva dopo.
	if _scena != "carte":
		var packed: PackedScene = load("res://game/play.tscn")
		play = packed.instantiate()
		# Anche la scena `dialogo` parte senza: il fumetto lo apre lei a mano
		# sulla battuta che le serve, invece di subire le centoventi
		# dell'introduzione.
		play.senza_dialoghi = true
		root.add_child(play)
		current_scene = play


func _finalize() -> void:
	_rimetti_a_posto_il_salvataggio()


func _process(_delta: float) -> bool:
	_frames += 1

	match _scena:
		"battaglia":
			_copione_battaglia()
		"bottega":
			_copione_bottega()
		"carte":
			_copione_carte()
		"incontro":
			_copione_incontro()
		"dialogo":
			_copione_dialogo()
		_:
			push_error("scena sconosciuta: %s — battaglia · bottega · carte · incontro · dialogo" % _scena)
			quit(1)
			return true

	if _registra and _frames % PASSO == 0:
		_scatta()

	if _scatti >= _quanti:
		print("[CLIP] %s: %d fotogrammi in %s" % [_scena, _scatti, _dir])
		quit(0)
		return true
	if _frames > 12000:
		print("[CLIP] %s: la sequenza non è mai partita (%d fotogrammi)" % [_scena, _scatti])
		quit(1)
		return true
	return false


# --- i copioni -----------------------------------------------------------
#
# I numeri sono sessantesimi di secondo dall'avvio.

## La battaglia vera, dalla prima carta che spara. È l'unica scena che si muove
## da sola: qui il copione non pilota niente, aspetta.
func _copione_battaglia() -> void:
	if _frames != 5:
		return
	play.run.round_number = 3
	play._start_battle()
	# La velocità si impone al duello appena creato e **non** scrivendo
	# `options.battle_speed`: quella è un'impostazione dell'utente, sta nel
	# salvataggio, e uno strumento non gliela cambia per sempre senza dirglielo.
	play.duel.speed_up(1.0)
	# Si comincia alla prima carta che parte: prima c'è solo un tavolo fermo.
	play.duel.card_activated.connect(func(_s, _i, _c) -> void:
		_registra = true
	)


## La bottega: la scheda che si apre su tre carte diverse, poi un acquisto —
## l'oro che scende, la vetrina che si rifà — e il mazzo che si apre a mostrare
## la carta appena entrata.
func _copione_bottega() -> void:
	match _frames:
		3:
			play.run.earn(140)
		6:
			play._apri_bottega()
			# La lezione di GiGi qui coprirebbe metà schermata: la clip mostra
			# la bottega, non il tutorial.
			play._dialogo.chiudi()
		30:
			_registra = true
		42:
			_passa_sopra(0)
		162:
			_passa_sopra(1)
		282:
			_passa_sopra(2)
		402:
			# La scheda si chiude **prima** dell'acquisto: `_refresh_shop()`
			# libera le viste della vetrina, e una scheda ancorata a una di
			# quelle resterebbe appesa a un rettangolo che non esiste più.
			play._detail.nascondi()
			play._on_buy_card(2)
		462:
			play._toggle_overlay(play.Overlay.DECK)


## I quattro mazzi, con la scheda che ci passa sopra uno per uno: è il confronto
## fra una carta di città e una di campagna, letto sui numeri.
func _copione_carte() -> void:
	if _frames == 1:
		_monta_catalogo()
		return
	if _frames == 20:
		_registra = true
	if _frames < 30 or _catalogo.is_empty():
		return
	var passo := (_frames - 30) / 132
	if passo < _catalogo.size() and (_frames - 30) % 132 == 0:
		_apri_scheda(_catalogo[passo])


## Un incontro: l'illustrazione, le scelte, e l'esito che prende il posto della
## scena — la scelta «Accetta la sfida» ha un disegno suo.
func _copione_incontro() -> void:
	match _frames:
		6:
			play._show_event(_voce("events", "giocatore"))
		20:
			_registra = true
		320:
			play._on_event_choice(_voce("events", "giocatore"), 0)


## Il fumetto dell'introduzione, con la macchina da scrivere che gira davvero.
## `_tocca()` è quello che fa il click del giocatore: se sta ancora scrivendo
## finisce la battuta, altrimenti passa alla prossima.
func _copione_dialogo() -> void:
	match _frames:
		6:
			var scena := _voce("dialoghi", "inizio")
			# La bottega va tolta di mezzo. Giocando, l'introduzione al bar va in
			# scena **prima** che la bottega esista; qui invece `senza_dialoghi`
			# ha già portato la partita in vetrina, e dietro al velo si
			# leggerebbero prezzi e reliquie mentre il gestore parla del bar.
			play._shop_panel.visible = false
			play._metti_sfondo(String(scena.get("sfondo", "")))
			play._dialogo.mostra(scena)
			# La prima battuta è una didascalia: quello che si vuole vedere è
			# un volto con la sua targa, e comincia dalla seconda.
			play._dialogo._tocca()
			play._dialogo._tocca()
		20:
			_registra = true
	if _frames > 20 and (_frames - 20) % 150 == 0:
		play._dialogo._tocca()


# --- il catalogo delle carte ---------------------------------------------

## Quattro carte costruite a mano, senza passare da una partita: qui non serve
## una run, serve un confronto. Stessa cucina di `foto_gaiofanamon.gd` — le
## classi si prendono con `load()` e si tengono in variabili senza tipo.
func _monta_catalogo() -> void:
	var lib: Object = load("res://game/logic/card_library.gd")
	var vista_cls: Object = load("res://game/ui/card_view.gd")
	var scheda_cls: Object = load("res://game/ui/card_detail.gd")
	var pal: Object = load("res://core/ui/palette.gd")

	var sfondo := TextureRect.new()
	sfondo.texture = load("res://game/art/sfondi/bottega.png")
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	sfondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sfondo.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(sfondo)

	var velo := ColorRect.new()
	velo.color = Color(pal.BG_DEEP.r, pal.BG_DEEP.g, pal.BG_DEEP.b, 0.68)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(velo)

	# Due righe da due, e non quattro in fila: la scheda si apre **di fianco**
	# alla carta ed è larga 260 — quattro carte affiancate se la coprirebbero a
	# vicenda, e sparirebbe proprio quella con cui si sta facendo il confronto.
	# Posizioni scritte a mano, senza contenitori: qui non c'è niente da
	# ridisporre, e un `Container` riscriverebbe le posizioni a ogni riordino.
	for i in CARTE.size():
		var card: Object = lib.build(String(CARTE[i][1]))
		if card == null:
			push_error("carta inesistente: %s" % CARTE[i][1])
			continue
		var casa := Vector2(200 + (i % 2) * 400, 90 + (i / 2) * 300)

		var etichetta := Label.new()
		etichetta.text = String(CARTE[i][0]).to_upper()
		etichetta.position = casa - Vector2(0, 26)
		etichetta.add_theme_font_size_override("font_size", pal.FONT_SMALL)
		etichetta.add_theme_color_override("font_color", pal.TEXT_DIM)
		root.add_child(etichetta)

		var vista: Control = vista_cls.new(card, false, 1)  # Mode.SHOP
		vista.position = casa
		root.add_child(vista)
		_catalogo.append(vista)

	_scheda = scheda_cls.new()
	root.add_child(_scheda)


## Apre la scheda di fianco a una carta del catalogo. Il rettangolo si chiede
## **ora** e non al montaggio: prima che la carta sia stata disposta sta ancora
## a (0,0), e la scheda si aprirebbe nell'angolo.
func _apri_scheda(vista: Control) -> void:
	if _scheda == null or not is_instance_valid(vista):
		return
	_scheda.mostra(vista.card, vista.get_global_rect())


# --- utilità -------------------------------------------------------------

## La carta n-esima della vetrina, ripescata nell'albero a ogni uso: la bottega
## si ricostruisce da capo a ogni `_refresh_shop()`, e un riferimento preso
## prima sarebbe già morto.
func _passa_sopra(indice: int) -> void:
	var carte := _carte_a_schermo(play)
	if indice < carte.size():
		play._on_card_hovered(carte[indice])


## Tutte le `CardView` a schermo, in ordine d'albero. Si riconoscono dal
## percorso del loro script e **non** con `is CardView`, per la stessa ragione
## di `foto_schermate.gd`: nominare la classe qui obbligherebbe Godot a
## compilare `card_view.gd` insieme a questo file, e quello usa gli autoload —
## che quando il MainLoop viene compilato non esistono ancora.
func _carte_a_schermo(node: Node, dentro: Array = []) -> Array:
	for child in node.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with("card_view.gd") \
				and child.card != null and child.is_visible_in_tree():
			dentro.append(child)
		_carte_a_schermo(child, dentro)
	return dentro


func _voce(archivio: String, id: String) -> Dictionary:
	return root.get_node("Content").entry(archivio, id)


## Il disegno si **chiede**, non si aspetta: `force_draw` disegna adesso, e
## `get_texture()` subito dopo restituisce proprio questo fotogramma. Lasciando
## fare a Godot, che salta i disegni quando è in ritardo, il tempo fra uno
## scatto e l'altro lo deciderebbe la velocità del disco.
func _scatta() -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("%s/f%03d.png" % [_dir, _scatti])
	_scatti += 1


func _metti_da_parte_il_salvataggio() -> void:
	if not FileAccess.file_exists(SALVATAGGIO):
		return
	if DirAccess.copy_absolute(SALVATAGGIO, MESSO_DA_PARTE) == OK:
		_spostato = true


func _rimetti_a_posto_il_salvataggio() -> void:
	if not _spostato:
		return
	if DirAccess.copy_absolute(MESSO_DA_PARTE, SALVATAGGIO) == OK:
		DirAccess.remove_absolute(MESSO_DA_PARTE)
