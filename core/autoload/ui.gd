extends Node
## Tema globale, toast e scorciatoie per costruire interfacce in poche righe.
##
##   var riga := Ui.hbox([
##       Ui.heading("Negozio"),
##       Ui.spacer(),
##       Ui.button("Reroll", _on_reroll),
##   ])
##
## Costruire la UI in codice invece che in scene .tscn è voluto: un pannello si
## legge e si modifica in un punto solo, e resta leggibile in diff.

const TOAST_DURATION := 2.0

var theme_resource: Theme

var _toast_layer: CanvasLayer
var _toast_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_theme()
	_build_toast_layer()
	Events.toast_requested.connect(_on_toast_requested)
	Events.shake_requested.connect(_on_shake_requested)


## Ricostruisce il tema da Palette e lo riapplica (F5 lo chiama).
func apply_theme() -> void:
	theme_resource = ThemeBuilder.build()
	get_tree().root.theme = theme_resource
	RenderingServer.set_default_clear_color(Palette.BG_DEEP)


## Quanto è largo il riquadro dei messaggi che compaiono in alto.
const TOAST_LARGHEZZA := 400


# --- testo --------------------------------------------------------------

func label(text: String, size: int = Palette.FONT_BODY, color: Color = Palette.TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


func title(text: String) -> Label:
	return label(text, Palette.FONT_TITLE)


func heading(text: String) -> Label:
	return label(text, Palette.FONT_HEADING)


func dim(text: String, size: int = Palette.FONT_SMALL) -> Label:
	return label(text, size, Palette.TEXT_DIM)


# --- controlli ----------------------------------------------------------

## `on_pressed` può essere omessa e collegata dopo.
##
## **Qui NON va messo `clip_text`**, per quanto sembri la cosa giusta da fare
## in vista di una traduzione. In Godot un Button con `clip_text` (o con un
## overrun diverso da NO_TRIMMING) azzera la propria larghezza minima: un
## bottone che non ha un `custom_minimum_size` suo e non è stirato da un
## genitore **collassa a 8 px**. Provato e visto: «Vedi mazzo» e «Vedi
## reliquie», che stanno in una riga fra due spaziatori, sparivano in due
## schegge, e con loro il modo di aprire il mazzo. Nessun errore in console.
##
## Dove il taglio serve davvero si chiede con `larghezza`: quella diventa la
## dimensione minima del bottone E accende il taglio, cosi' le due cose non
## possono separarsi e nessuno si ritrova con un bottone da 8 px.
func button(text: String, on_pressed: Callable = Callable(),
		larghezza: int = 0) -> Button:
	var node := Button.new()
	node.text = text
	if larghezza > 0:
		node.custom_minimum_size.x = larghezza
		node.clip_text = true
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	node.pressed.connect(func() -> void: Audio.sfx("click"))
	node.mouse_entered.connect(func() -> void: Audio.sfx("hover"))
	return node


func bar(value: float, max_value: float, color: Color = Palette.ACCENT, height: int = 14) -> ProgressBar:
	var node := ProgressBar.new()
	node.max_value = maxf(max_value, 0.001)
	node.value = value
	node.show_percentage = false
	node.custom_minimum_size.y = height
	node.add_theme_stylebox_override("fill", ThemeBuilder.box(color, Color.TRANSPARENT, Palette.RADIUS_SMALL))
	return node


## Quadrato colorato con una scritta al centro: è così che si rappresentano
## unità, torri e nemici finché non arriva la grafica vera.
func token(text: String, color: Color, size: int = 56) -> PanelContainer:
	var node := PanelContainer.new()
	node.custom_minimum_size = Vector2(size, size)
	node.add_theme_stylebox_override("panel", ThemeBuilder.box(color, color.lightened(0.3), Palette.RADIUS, Palette.BORDER_WIDTH))

	var text_node := label(text, int(size * 0.4), Palette.BG_DEEP)
	text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_child(text_node)
	return node


# --- contenitori --------------------------------------------------------

func vbox(children: Array = [], gap: int = Palette.GAP) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	for child in children:
		if child is Node:
			node.add_child(child)
	return node


func hbox(children: Array = [], gap: int = Palette.GAP) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	for child in children:
		if child is Node:
			node.add_child(child)
	return node


func grid(columns: int, children: Array = [], gap: int = Palette.GAP) -> GridContainer:
	var node := GridContainer.new()
	node.columns = maxi(columns, 1)
	node.add_theme_constant_override("h_separation", gap)
	node.add_theme_constant_override("v_separation", gap)
	for child in children:
		if child is Node:
			node.add_child(child)
	return node


func panel(child: Control, fill: Color = Palette.SURFACE) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", ThemeBuilder.box(fill, Palette.BORDER, Palette.RADIUS, Palette.BORDER_WIDTH))
	node.add_child(child)
	return node


## Spazio elastico: spinge via ciò che viene dopo.
func spacer(minimum: int = 0) -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size = Vector2(minimum, minimum)
	return node


func margin(child: Control, amount: int = Palette.PAD) -> MarginContainer:
	var node := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		node.add_theme_constant_override("margin_" + side, amount)
	node.add_child(child)
	return node


## Centra il figlio solo in orizzontale, lasciandolo alla sua altezza.
func center_row(child: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(child)
	return row


## Centra il figlio nello spazio disponibile.
func center(child: Control) -> CenterContainer:
	var node := CenterContainer.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(child)
	return node


## Estende il controllo a tutto lo schermo.
func fullscreen(control: Control) -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	return control


func background(color: Color = Palette.BG) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


# --- toast --------------------------------------------------------------

func _build_toast_layer() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 90
	add_child(_toast_layer)

	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_left = -TOAST_LARGHEZZA / 2.0
	_toast_box.offset_right = TOAST_LARGHEZZA / 2.0
	_toast_box.offset_top = 24
	_toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(_toast_box)


func _on_toast_requested(text: String, kind: String) -> void:
	var color := Palette.ACCENT
	match kind:
		"good": color = Palette.SUCCESS
		"bad": color = Palette.DANGER
		"warn": color = Palette.WARNING

	var text_node := label(text, Palette.FONT_BODY, Palette.BG_DEEP)
	text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Il riquadro è largo 400 px fissi. Senza andare a capo, una frase più
	# lunga esce dal colore e resta sospesa sullo sfondo: succede già oggi in
	# italiano con i messaggi lunghi, e in tedesco succederebbe con quasi tutti.
	text_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_node.custom_minimum_size.x = TOAST_LARGHEZZA - Palette.PAD * 2

	var toast := PanelContainer.new()
	toast.add_theme_stylebox_override("panel", ThemeBuilder.box(color, Color.TRANSPARENT, Palette.RADIUS))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(text_node)
	_toast_box.add_child(toast)

	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.12).from(0.0)
	tween.tween_interval(TOAST_DURATION)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast.queue_free)


# --- scossa -------------------------------------------------------------

## Scuote la scena corrente. In giochi di sola UI non c'è una Camera2D da
## muovere, quindi si sposta direttamente il nodo radice della scena.
func _on_shake_requested(strength: float, duration: float) -> void:
	var target := get_tree().current_scene
	if not (target is CanvasItem):
		return

	var origin: Variant = target.get("position")
	if not (origin is Vector2):
		return

	var tween := create_tween()
	var steps := maxi(int(duration / 0.04), 1)
	for i in steps:
		var decay := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * decay
		tween.tween_property(target, "position", origin + offset, 0.04)
	tween.tween_property(target, "position", origin, 0.04)
