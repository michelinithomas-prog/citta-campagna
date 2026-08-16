extends Node
## Strumenti di debug. In una jam sono ciò che fa risparmiare più tempo.
##
##   F1  overlay (fps, seed, valori sotto osservazione)
##   F2  console comandi
##   F5  ricarica tuning.json, i contenuti e il tema — senza riavviare
##   F8  ricomincia la partita
##   F9  screenshot in user://
##
## Da registrare nel gioco:
##   Dbg.watch("Oro", func(): return wallet.get_amount("gold"))
##   Dbg.command("give", func(args): wallet.earn("gold", float(args[0])), "give <n>")
##
## Si spegne dal project.godot con [game] debug/enabled=false.

var enabled := true

var _overlay: CanvasLayer
var _overlay_text: Label
var _console: CanvasLayer
var _console_output: RichTextLabel
var _console_input: LineEdit

var _watches: Dictionary = {}
var _watch_order: Array[String] = []
var _commands: Dictionary = {}
var _command_help: Dictionary = {}
var _builtin_commands: Dictionary = {}
var _history: Array[String] = []
var _history_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = bool(ProjectSettings.get_setting("game/debug/enabled", OS.is_debug_build()))
	if not enabled:
		return

	_build_overlay()
	_build_console()
	_register_builtin_commands()


func _process(_delta: float) -> void:
	if _overlay != null and _overlay.visible:
		_overlay_text.text = _compose_overlay_text()


func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match (event as InputEventKey).keycode:
		KEY_F1:
			_overlay.visible = not _overlay.visible
		KEY_F2:
			_toggle_console()
		KEY_F5:
			reload_all()
		KEY_F7:
			lingua_finta(not TranslationServer.is_pseudolocalization_enabled())
		KEY_F8:
			Router.replay_run()
			log_line("rigiocata la stessa partita (seed %d)" % Rng.seed_value)
		KEY_F9:
			screenshot()
		_:
			return
	get_viewport().set_input_as_handled()


# --- API ----------------------------------------------------------------

## Mostra un valore nell'overlay. `getter` viene chiamata ogni frame.
func watch(label: String, getter: Callable) -> void:
	if not _watches.has(label):
		_watch_order.append(label)
	_watches[label] = getter


func unwatch(label: String) -> void:
	_watches.erase(label)
	_watch_order.erase(label)


func clear_watches() -> void:
	_watches.clear()
	_watch_order.clear()


## Osservazioni e comandi registrati da una scena valgono solo per quella scena:
## il Router chiama questo a ogni cambio, altrimenti i Callable resterebbero qui
## a puntare a nodi ormai liberati.
func clear_scene_hooks() -> void:
	clear_watches()
	for name in _commands.keys():
		if not _builtin_commands.has(name):
			_commands.erase(name)
			_command_help.erase(name)


## `handler` riceve un Array[String] con gli argomenti.
func command(name: String, handler: Callable, help_text: String = "") -> void:
	_commands[name] = handler
	_command_help[name] = help_text if not help_text.is_empty() else name


func log_line(text: String) -> void:
	if _console_output != null:
		_console_output.append_text(text + "\n")
	print(text)


## Accende la lingua finta: le stringhe si allungano del 30% e si riempiono di
## accenti, come farebbe un tedesco.
##
## Serve a vedere **cosa si rompe in una lingua che non abbiamo ancora**. Un
## layout che regge l'italiano non regge niente: l'italiano è una delle lingue
## più corte fra quelle che ci interessano, e una traduzione che sfora si
## scopre il giorno che arriva, quando rifare i pannelli costa dieci volte
## tanto. Con questa accesa il difetto si vede adesso, a costo zero.
func lingua_finta(accesa: bool) -> void:
	TranslationServer.set_pseudolocalization_enabled(accesa)
	# I Control ripescano il testo alla notifica di traduzione cambiata, ma i
	# pannelli si ridimensionano solo al giro di layout dopo: senza questo la
	# schermata resta larga com'era e il difetto che stiamo cercando non si
	# vede proprio.
	Ui.apply_theme()
	log_line("lingua finta: %s" % ("accesa" if accesa else "spenta"))
	Events.toast("Lingua finta %s" % ("ON" if accesa else "OFF"), "info")


## Rilegge tuning, contenuti e tema senza riavviare il gioco.
func reload_all() -> void:
	Cfg.reload()
	Content.reload()
	Ui.apply_theme()
	log_line("ricaricati tuning + contenuti + tema")
	Events.toast("Ricaricato", "good")


func screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	var path := "user://screenshot_%d.png" % Time.get_ticks_msec()
	image.save_png(path)
	log_line("screenshot: %s" % ProjectSettings.globalize_path(path))


# --- overlay ------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 95
	_overlay.visible = false
	add_child(_overlay)

	_overlay_text = Ui.label("", Palette.FONT_SMALL, Palette.SUCCESS)
	_overlay_text.position = Vector2(10, 8)
	_overlay_text.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	_overlay_text.add_theme_constant_override("outline_size", 4)
	_overlay.add_child(_overlay_text)


func _compose_overlay_text() -> String:
	var lines: Array[String] = []
	lines.append("%d fps   seed %d" % [Engine.get_frames_per_second(), Rng.seed_value])
	for label in _watch_order:
		var getter: Callable = _watches[label]
		lines.append("%s: %s" % [label, getter.call() if getter.is_valid() else "?"])
	for error in Content.errors():
		lines.append("[!] " + error)
	return "\n".join(lines)


# --- console ------------------------------------------------------------

func _build_console() -> void:
	_console = CanvasLayer.new()
	_console.layer = 96
	_console.visible = false
	add_child(_console)

	_console_output = RichTextLabel.new()
	_console_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_console_output.custom_minimum_size.y = 180
	_console_output.scroll_following = true
	_console_output.add_theme_font_size_override("normal_font_size", Palette.FONT_SMALL)

	_console_input = LineEdit.new()
	_console_input.placeholder_text = "comando…  (help)"
	_console_input.text_submitted.connect(_on_command_submitted)
	_console_input.gui_input.connect(_on_console_input_key)

	var box := Ui.vbox([_console_output, _console_input], Palette.PAD_SMALL)
	var frame := Ui.panel(box, Palette.fade(Palette.BG_DEEP, 0.94))
	frame.set_anchors_preset(Control.PRESET_TOP_WIDE)
	frame.offset_bottom = 240

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(frame)
	_console.add_child(root)


func _toggle_console() -> void:
	_console.visible = not _console.visible
	if _console.visible:
		_console_input.grab_focus()
	else:
		_console_input.release_focus()


func _on_console_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := (event as InputEventKey).keycode
	if key != KEY_UP and key != KEY_DOWN:
		return
	if _history.is_empty():
		return

	_history_index = clampi(_history_index + (-1 if key == KEY_UP else 1), 0, _history.size() - 1)
	_console_input.text = _history[_history_index]
	_console_input.caret_column = _console_input.text.length()
	_console_input.accept_event()


func _on_command_submitted(text: String) -> void:
	_console_input.clear()
	var line := text.strip_edges()
	if line.is_empty():
		return

	_history.append(line)
	_history_index = _history.size()
	log_line("> " + line)

	var parts := line.split(" ", false)
	var name := parts[0]
	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	if not _commands.has(name):
		log_line('comando sconosciuto: "%s" — prova "help"' % name)
		return
	(_commands[name] as Callable).call(args)


func _register_builtin_commands() -> void:
	command("help", func(_args: Array) -> void:
		var names := _command_help.keys()
		names.sort()
		for name in names:
			log_line("  %s" % _command_help[name])
	, "help — elenca i comandi")

	command("reload", func(_args: Array) -> void: reload_all(), "reload — ricarica dati e tema")

	command("restart", func(_args: Array) -> void: Router.start_new_run(), "restart — partita nuova")

	command("replay", func(_args: Array) -> void: Router.replay_run(), "replay — rigioca lo stesso seed")

	command("scene", func(args: Array) -> void:
		if args.is_empty():
			log_line("scena corrente: %s" % Router.current_key)
		else:
			Router.goto(args[0])
	, "scene [menu|play|game_over] — cambia scena")

	command("seed", func(args: Array) -> void:
		if args.is_empty():
			log_line("seed: %d" % Rng.seed_value)
		else:
			Router.start_new_run(int(args[0]))
	, "seed [n] — nuova partita con un seed preciso")

	command("wipe", func(_args: Array) -> void:
		Save.wipe()
		log_line("salvataggio cancellato")
	, "wipe — cancella il salvataggio")

	command("quit", func(_args: Array) -> void: get_tree().quit(), "quit — chiude il gioco")

	# Da qui in poi tutto ciò che si registra appartiene alla scena corrente.
	for name in _commands:
		_builtin_commands[name] = true
