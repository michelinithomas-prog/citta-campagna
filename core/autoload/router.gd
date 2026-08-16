extends Node
## Cambio scena con dissolvenza, pausa e restart.
##
##   Router.goto("game")                      # scena definita nel project.godot
##   Router.game_over(true, {"score": 120})   # va alla schermata di fine partita
##   Router.restart()
##
## Le scene si dichiarano nel project.godot di ogni template, così il core non
## sa nulla del gioco che sta ospitando:
##
##   [game]
##   scenes/menu="res://game/ui/main_menu.tscn"
##   scenes/play="res://game/play.tscn"
##   scenes/game_over="res://game/ui/game_over.tscn"

const FADE_TIME := 0.25

signal scene_changed(key: String)

## Riempito da game_over(), letto dalla schermata di fine partita.
var last_run_won := false
var last_run_stats: Dictionary = {}
var current_key := ""

var _fade: ColorRect
var _pause_layer: CanvasLayer
var _pause_menu: Control
var _busy := false
var _pending_key := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_build_fade_layer()
	_build_pause_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and current_key == "play":
		toggle_pause()
		get_viewport().set_input_as_handled()


# --- navigazione --------------------------------------------------------

func scene_path(key: String) -> String:
	return String(ProjectSettings.get_setting("game/scenes/" + key, ""))


func goto(key: String) -> void:
	var path := scene_path(key)
	if path.is_empty():
		push_error('Router: nessuna scena "%s" nel project.godot (sezione [game], scenes/%s)' % [key, key])
		return

	# Una transizione dura ~mezzo secondo: se ne arriva un'altra nel frattempo
	# va messa in coda, non buttata via — altrimenti current_key e la scena
	# davvero visibile finiscono per non corrispondere più.
	if _busy:
		_pending_key = key
		return

	_change_scene(key, path)


func game_over(won: bool, stats: Dictionary = {}) -> void:
	last_run_won = won
	last_run_stats = stats
	Events.run_ended.emit(won, stats)
	set_paused(false)
	Audio.sfx("win" if won else "lose")
	goto("game_over")


## Inizia una partita nuova. Seed 0 = casuale.
func start_new_run(run_seed: int = 0) -> void:
	set_paused(false)
	var value := Rng.new_run(run_seed)
	Events.run_started.emit(value)
	goto("play")


## Rigioca la stessa identica partita: stesso seed, stesse pescate, stessi
## spawn. È il modo per riprodurre un bug visto un minuto prima (F8).
func replay_run() -> void:
	start_new_run(Rng.seed_value)


## Ricarica la scena corrente senza toccare il seed.
func restart() -> void:
	set_paused(false)
	if current_key.is_empty():
		get_tree().reload_current_scene()
	else:
		goto(current_key)


func _change_scene(key: String, path: String) -> void:
	_busy = true

	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished

	Dbg.clear_scene_hooks()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	current_key = key
	scene_changed.emit(key)

	var tween_out := create_tween()
	tween_out.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await tween_out.finished
	_busy = false

	if not _pending_key.is_empty():
		var next := _pending_key
		_pending_key = ""
		goto(next)


# --- pausa --------------------------------------------------------------

func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func set_paused(value: bool) -> void:
	get_tree().paused = value
	_pause_menu.visible = value
	Events.pause_toggled.emit(value)


# --- costruzione --------------------------------------------------------

func _build_fade_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(Palette.BG_DEEP, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 80
	add_child(_pause_layer)

	var content := Ui.vbox([
		Ui.heading("Pausa"),
		Ui.button("Riprendi", func() -> void: set_paused(false)),
		Ui.button("Ricomincia", func() -> void: start_new_run()),
		Ui.button("Menu principale", func() -> void: set_paused(false); goto("menu")),
	], Palette.PAD)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.custom_minimum_size.x = 220

	var veil := Ui.background(Palette.fade(Palette.BG_DEEP, 0.75))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP

	_pause_menu = Control.new()
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_menu.visible = false
	_pause_menu.add_child(veil)
	_pause_menu.add_child(Ui.center(Ui.panel(content)))
	_pause_layer.add_child(_pause_menu)


## Le azioni si registrano qui invece che nel project.godot di ogni template:
## una sola definizione, valida per tutti e quattro.
func _ensure_input_actions() -> void:
	_add_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	_add_action("confirm", [KEY_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_add_action("speed_up", [KEY_TAB], [JOY_BUTTON_RIGHT_SHOULDER])


func _add_action(name: String, keys: Array, buttons: Array = []) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(name, event)
	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(name, event)
