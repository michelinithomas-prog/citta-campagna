extends Control
## Menu principale di Città & Campagna.
##
## Una scena sola con tre schermate che si accendono a turno — menu, setting,
## credits — più un pannellino di conferma davanti a tutto, perché "New Game"
## con una partita salvata sul disco è una cosa che non si fa per sbaglio.
##
## Titolo e sottotitolo non sono scritti qui: arrivano dal nome del progetto e
## da game/data/tuning.json, così questo file non si tocca per ritematizzare.
##
##   {"menu": {"subtitle": "...", "best_key": "rounds", "best_label": "Miglior round"}}

const SFONDO := "res://game/art/sfondi/menu.png"
const LOGO := "res://game/art/ui/logo.png"
## Il logo è 1409×975: queste sono le stesse proporzioni, grandi quanto basta a
## leggere "MEGACORP" lasciando sotto lo spazio per i bottoni.
const MISURA_LOGO := Vector2(520, 360)
const VELO := 0.34

const BUTTON_SIZE := Vector2(190, 46)
const WIDE_BUTTON_SIZE := Vector2(200, 40)
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const SPEED_PATH := "options.battle_speed"
## I nomi che Audio.set_volume() si aspetta (bus Master / Music / SFX).
const VOLUME_BUSES := [["master", "Volume generale"], ["music", "Musica"], ["sfx", "Effetti"]]
## Il valzer del menu. È un nome, non un percorso: lo risolve Audio in
## game/audio/, come fa per gli effetti.
const MUSICA := "musica_menu"

## Chi ha fatto il gioco, in ordine alfabetico di cognome perché un ordine
## qualunque sarebbe stato una graduatoria.
const AUTORI := [
	"Gabriele Baffoni",
	"Matteo Masini",
	"Thomas Michelini",
	"Luca Tamburini",
]

var _pages: Dictionary = {}
## Bottone su cui posare il fuoco quando una schermata compare: così Invio
## fa la cosa ovvia senza toccare il mouse.
var _focus_targets: Dictionary = {}
var _confirm: Control
var _confirm_focus: Button
## Vero solo sul web, finché non arriva il primo gesto: vedi _ready().
var _musica_da_avviare := false
var _current_page := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Hud.tema()
	add_child(Ui.background(Hud.LEGNO_SCURO))
	_costruisci_sfondo()

	_pages["main"] = _build_main_page()
	_pages["settings"] = _build_settings_page()
	_pages["credits"] = _build_credits_page()
	for key: String in ["main", "settings", "credits"]:
		add_child(_pages[key])

	_confirm = _build_confirm_panel()
	add_child(_confirm)

	_show_page("main")

	# Sul desktop la musica parte subito. Sul web no: il browser tiene sospeso
	# l'AudioContext finché non arriva un gesto dell'utente, e una traccia
	# avviata prima scorrerebbe muta. Lì si aspetta il primo tasto o il primo
	# clic — che nel menu principale arriva comunque entro un istante.
	if OS.has_feature("web"):
		_musica_da_avviare = true
	else:
		Audio.music(MUSICA)


## Il primo gesto dell'utente, sul web, è quello che sblocca l'audio.
##
## Sta in `_input` e non in `_unhandled_input`, ed è la differenza fra avere la
## musica e non averla: `_unhandled_input` vede solo gli eventi che nessun
## Control ha consumato, e qui il menu è tutto bottoni sopra uno sfondo che
## ferma il mouse. Chi giocava col mouse — cioè quasi tutti — non faceva mai
## arrivare un evento fin lì, e restava senza musica per l'intera partita.
## Con la tastiera invece partiva: è la ragione per cui in prova sembrava a posto.
func _input(event: InputEvent) -> void:
	if not _musica_da_avviare:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		_musica_da_avviare = false
		Audio.music(MUSICA)


## ESC torna indietro di un passo: prima chiude la conferma, poi la sottopagina.
func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		return
	if _confirm.visible:
		_close_confirm()
	elif _current_page != "main":
		_show_page("main")
	else:
		return
	Audio.sfx("cancel")
	get_viewport().set_input_as_handled()


# --- schermate ----------------------------------------------------------

func _show_page(key: String) -> void:
	_current_page = key
	for name: String in _pages:
		_pages[name].visible = name == key
	var target: Variant = _focus_targets.get(key)
	if target is Button and not (target as Button).disabled:
		(target as Button).call_deferred("grab_focus")


##      +------------------------------------------+
##      |               T I T O L O                |
##      |     [ New Game ]      [ Continua ]       |
##      |            [ Setting ]                   |
##      |            [ Credits ]                   |
##      +------------------------------------------+
func _build_main_page() -> Control:
	var column := Ui.vbox([], Palette.PAD * 2)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = 520

	column.add_child(_title_frame())

	var new_game := Ui.button("New Game", _on_new_game)
	new_game.custom_minimum_size = BUTTON_SIZE

	var has_save := _has_saved_run()
	var continue_button := Ui.button("Continua", _on_continue)
	continue_button.custom_minimum_size = BUTTON_SIZE
	continue_button.disabled = not has_save

	var row := Ui.hbox([new_game, continue_button], Palette.PAD)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	var hint := Ui.dim("Nessuna partita salvata" if not has_save else "Riprendi da dove eri rimasto")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	var setting_button := Ui.button("Setting", func() -> void: _show_page("settings"))
	setting_button.custom_minimum_size = WIDE_BUTTON_SIZE
	var credits_button := Ui.button("Credits", func() -> void: _show_page("credits"))
	credits_button.custom_minimum_size = WIDE_BUTTON_SIZE

	var stack := Ui.vbox([Ui.center_row(setting_button), Ui.center_row(credits_button)], Palette.PAD_SMALL)
	column.add_child(stack)

	_focus_targets["main"] = new_game
	return Ui.center(column)


## Il bar di Gaiofana dietro al menu, con un velo sopra.
##
## Il velo non è decorazione: l'illustrazione ha un cielo azzurro pieno di luce,
## e i bottoni di legno scuro ci sparirebbero dentro. Sotto il velo il legno
## torna a staccarsi e il logo resta la cosa più chiara dello schermo.
func _costruisci_sfondo() -> void:
	if not ResourceLoader.exists(SFONDO):
		return

	var sfondo := TextureRect.new()
	sfondo.texture = load(SFONDO)
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	sfondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sfondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVERED: riempie sempre, anche a schermo intero su un monitor di
	# proporzioni diverse. Meglio perderne un pezzo ai bordi che due bande nere.
	sfondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(sfondo)

	var velo := Ui.background(Hud.INCHIOSTRO)
	velo.color.a = VELO
	add_child(velo)


## Il logo del gioco, o il titolo scritto se il file non c'è.
##
## Il logo dice già come si chiama il gioco e contro chi si gioca: attorno non ci
## va nessuna cornice di legno, e sotto resta solo il record — il sottotitolo
## ripeterebbe quello che l'illustrazione ha già detto meglio.
func _title_frame() -> Control:
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.texture = load(LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = MISURA_LOGO
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return Ui.vbox([logo, Ui.center_row(_best_score_label())], Palette.PAD_SMALL)

	return _titolo_scritto()


## Il ripiego di sempre: titolo, sottotitolo e record dentro una cornice.
func _titolo_scritto() -> Control:
	var game_name := String(ProjectSettings.get_setting("application/config/name", "Gioco"))
	var subtitle := String(Cfg.get_value("menu.subtitle", ""))

	var inner := Ui.vbox([], Palette.PAD_SMALL)

	var title := Ui.title(game_name)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	if not subtitle.is_empty():
		var subtitle_label := Ui.dim(subtitle, Hud.TESTO)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(subtitle_label)

	inner.add_child(_best_score_label())
	return Hud.cornice(Ui.margin(inner, Palette.PAD))


func _build_settings_page() -> Control:
	var column := Ui.vbox([], Palette.PAD)
	column.custom_minimum_size.x = 380

	var heading := Ui.heading("Setting")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	for bus: Array in VOLUME_BUSES:
		column.add_child(_volume_row(String(bus[0]), String(bus[1])))

	column.add_child(Ui.spacer(Palette.PAD_SMALL))
	column.add_child(Ui.dim("Velocità della battaglia", Hud.TESTO))
	column.add_child(_speed_row())
	column.add_child(Ui.spacer(Palette.PAD_SMALL))

	var back := Ui.button("Indietro", _on_back)
	back.custom_minimum_size = WIDE_BUTTON_SIZE
	column.add_child(Ui.center_row(back))

	_focus_targets["settings"] = back
	return Ui.center(Hud.cornice(Ui.margin(column, Palette.PAD)))


func _build_credits_page() -> Control:
	var game_name := String(ProjectSettings.get_setting("application/config/name", "Gioco"))

	var column := Ui.vbox([], Palette.PAD)
	column.custom_minimum_size.x = 380

	for line: Array in [
		[game_name, Hud.TESTO_GRANDE, Hud.CREMA],
		["game jam 2026", Hud.TESTO, Hud.CREMA_DIM],
		["carte da poker contro carte romagnole", Hud.TESTO, Hud.ORO],
	]:
		var node := Ui.label(String(line[0]), int(line[1]), line[2])
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(node)

	column.add_child(Ui.spacer(Palette.PAD_SMALL))

	# Nessun ruolo accanto ai nomi, ed è una scelta: il gioco è stato fatto in
	# quattro in un giorno, e dividerlo in caselle direbbe una cosa falsa.
	var etichetta := Ui.label("FATTO DA", Hud.TESTO_PICCOLO, Hud.CREMA_DIM)
	etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(etichetta)

	for persona: String in AUTORI:
		var node := Ui.label(persona, Hud.TESTO, Hud.CREMA)
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(node)

	column.add_child(Ui.spacer(Palette.PAD_SMALL))

	var back := Ui.button("Indietro", _on_back)
	back.custom_minimum_size = WIDE_BUTTON_SIZE
	column.add_child(Ui.center_row(back))

	_focus_targets["credits"] = back
	return Ui.center(Hud.cornice(Ui.margin(column, Palette.PAD)))


func _build_confirm_panel() -> Control:
	var message := Ui.label("Hai una partita in corso: ricominciare da capo?", Hud.TESTO)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = 340

	var restart := Ui.button("Ricomincia", func() -> void: _close_confirm(); _start_fresh())
	restart.custom_minimum_size = WIDE_BUTTON_SIZE
	var cancel := Ui.button("Annulla", func() -> void: Audio.sfx("cancel"); _close_confirm())
	cancel.custom_minimum_size = WIDE_BUTTON_SIZE

	var buttons := Ui.hbox([restart, cancel], Palette.PAD)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER

	var column := Ui.vbox([message, Ui.spacer(Palette.PAD_SMALL), buttons], Palette.PAD)

	var veil := Ui.background(Palette.fade(Hud.LEGNO_SCURO, 0.75))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP

	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.visible = false
	layer.add_child(veil)
	layer.add_child(Ui.center(Hud.cornice(Ui.margin(column, Palette.PAD))))

	_confirm_focus = cancel
	return layer


# --- pezzi del pannello setting -----------------------------------------

func _volume_row(bus: String, label_text: String) -> Control:
	var value_label := Ui.dim("", Hud.TESTO_PICCOLO)
	value_label.custom_minimum_size.x = 48
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Audio.get_volume(bus)
	slider.custom_minimum_size.x = 160
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		Audio.set_volume(bus, value)
		value_label.text = _percent(value)
	)
	value_label.text = _percent(slider.value)

	var name_label := Ui.dim(label_text, Hud.TESTO)
	name_label.custom_minimum_size.x = 130

	return Ui.hbox([name_label, Ui.spacer(), slider, value_label], Palette.PAD_SMALL)


## Tre bottoni a scelta singola: quello attivo resta premuto (stile "pressed").
func _speed_row() -> Control:
	var current := float(Save.get_value(SPEED_PATH, 1.0))
	# Un valore salvato fuori elenco non deve lasciare la riga senza selezione.
	var selected := 0
	for i in SPEEDS.size():
		if is_equal_approx(SPEEDS[i], current):
			selected = i

	var group := ButtonGroup.new()
	var row := Ui.hbox([], Palette.PAD_SMALL)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in SPEEDS.size():
		var speed := SPEEDS[i]
		var button := Ui.button("%dx" % int(speed))
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.x = 70
		button.button_pressed = i == selected
		button.pressed.connect(func() -> void: Save.set_value(SPEED_PATH, speed))
		row.add_child(button)
	return row


func _percent(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


# --- azioni -------------------------------------------------------------

func _on_new_game() -> void:
	if _has_saved_run():
		_open_confirm()
		return
	_start_fresh()


## Una partita nuova butta via quella vecchia: senza questo il salvataggio
## resterebbe su disco e "Continua" continuerebbe a offrire una partita che il
## giocatore ha appena deciso di abbandonare.
func _start_fresh() -> void:
	RunState.clear_save()
	Save.set_value("options.resume", false)
	Router.start_new_run()


## Il caricamento vero lo fa play.gd. Qui si alza la bandiera che gli dice di
## riprendere invece di ricominciare: senza, "Continua" farebbe partire una run
## nuova e il salvataggio verrebbe sovrascritto al primo passaggio in bottega.
func _on_continue() -> void:
	if not _has_saved_run():
		return
	Save.set_value("options.resume", true)
	Save.flush()
	Router.goto("play")


func _on_back() -> void:
	Audio.sfx("cancel")
	_show_page("main")


func _open_confirm() -> void:
	_confirm.visible = true
	if _confirm_focus != null:
		_confirm_focus.call_deferred("grab_focus")


func _close_confirm() -> void:
	_confirm.visible = false
	var target: Variant = _focus_targets.get(_current_page)
	if target is Button and not (target as Button).disabled:
		(target as Button).call_deferred("grab_focus")


# --- salvataggio --------------------------------------------------------

## La partita interrotta la conosce solo RunState (chiave "run" del salvataggio):
## il menu si limita a chiedere. Caricarla è compito di play.gd.
func _has_saved_run() -> bool:
	return RunState.has_saved()


# --- record -------------------------------------------------------------

func _best_score_label() -> Control:
	var key := String(Cfg.get_value("menu.best_key", "score"))
	var best := float(Save.get_value("best." + key, 0.0))
	if best <= 0.0:
		return Ui.spacer(0)

	# `best_label` arriva da tuning.json ed è solo un'etichetta: si traduce come
	# qualunque altra frase. `best_key` qui sopra no — è la chiave con cui il
	# record sta nel salvataggio.
	var etichetta := tr(String(Cfg.get_value("menu.best_label", "Record")))
	var text := tr("★ %s: %s") % [etichetta, _format_number(best)]
	var node := Ui.label(text, Hud.TESTO, Hud.ORO)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


func _format_number(value: float) -> String:
	if value >= 1000.0:
		return "%.1fk" % (value / 1000.0)
	return str(int(value))
