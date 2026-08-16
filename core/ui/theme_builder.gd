class_name ThemeBuilder
extends RefCounted
## Costruisce il Theme del gioco a partire da Palette.
##
## Il tema è generato a runtime invece che salvato in un .tres: così cambiare
## un colore in Palette lo propaga ovunque senza aprire l'editor, e F5 lo
## ricostruisce a caldo. Applicato da Ui al root della scena.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = Palette.FONT_BODY

	_style_button(theme)
	_style_panels(theme)
	_style_labels(theme)
	_style_progress(theme)
	_style_line_edit(theme)
	_style_slider(theme)
	_style_containers(theme)
	return theme


## Riquadro pieno: la base di quasi tutta la UI.
static func box(
	fill: Color,
	border_color: Color = Color.TRANSPARENT,
	radius: int = Palette.RADIUS,
	border: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if border > 0:
		style.set_border_width_all(border)
		style.border_color = border_color
	style.content_margin_left = Palette.PAD
	style.content_margin_right = Palette.PAD
	style.content_margin_top = Palette.PAD_SMALL
	style.content_margin_bottom = Palette.PAD_SMALL
	return style


static func _style_button(theme: Theme) -> void:
	var normal := box(Palette.SURFACE, Palette.BORDER, Palette.RADIUS, Palette.BORDER_WIDTH)
	var hover := box(Palette.SURFACE_HI, Palette.ACCENT, Palette.RADIUS, Palette.BORDER_WIDTH)
	var pressed := box(Palette.ACCENT_DIM, Palette.ACCENT, Palette.RADIUS, Palette.BORDER_WIDTH)
	var disabled := box(Palette.BG, Palette.BORDER, Palette.RADIUS, Palette.BORDER_WIDTH)
	disabled.bg_color.a = 0.5

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", box(Color.TRANSPARENT, Palette.ACCENT, Palette.RADIUS, Palette.BORDER_WIDTH))

	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.TEXT)
	theme.set_color("font_pressed_color", "Button", Palette.BG_DEEP)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_MUTED)
	theme.set_font_size("font_size", "Button", Palette.FONT_BODY)


static func _style_panels(theme: Theme) -> void:
	var panel := box(Palette.SURFACE, Palette.BORDER, Palette.RADIUS, Palette.BORDER_WIDTH)
	panel.content_margin_top = Palette.PAD
	panel.content_margin_bottom = Palette.PAD
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel.duplicate())

	var popup := box(Palette.BG, Palette.BORDER, Palette.RADIUS, Palette.BORDER_WIDTH)
	theme.set_stylebox("panel", "PopupPanel", popup)


static func _style_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_font_size("font_size", "Label", Palette.FONT_BODY)
	theme.set_color("default_color", "RichTextLabel", Palette.TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", Palette.FONT_BODY)
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())


static func _style_progress(theme: Theme) -> void:
	var background := box(Palette.BG_DEEP, Palette.BORDER, Palette.RADIUS_SMALL, 1)
	background.content_margin_left = 0
	background.content_margin_right = 0
	background.content_margin_top = 0
	background.content_margin_bottom = 0

	var fill := box(Palette.ACCENT, Color.TRANSPARENT, Palette.RADIUS_SMALL)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0

	theme.set_stylebox("background", "ProgressBar", background)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", Palette.TEXT)
	theme.set_font_size("font_size", "ProgressBar", Palette.FONT_SMALL)


static func _style_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", box(Palette.BG_DEEP, Palette.BORDER, Palette.RADIUS_SMALL, 1))
	theme.set_stylebox("focus", "LineEdit", box(Palette.BG_DEEP, Palette.ACCENT, Palette.RADIUS_SMALL, 1))
	theme.set_color("font_color", "LineEdit", Palette.TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_MUTED)
	theme.set_color("caret_color", "LineEdit", Palette.ACCENT)
	theme.set_font_size("font_size", "LineEdit", Palette.FONT_BODY)


static func _style_slider(theme: Theme) -> void:
	var slider := box(Palette.BG_DEEP, Palette.BORDER, Palette.RADIUS_SMALL, 1)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", slider)
	theme.set_stylebox("grabber_area", "HSlider", box(Palette.ACCENT, Color.TRANSPARENT, Palette.RADIUS_SMALL))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.ACCENT, Color.TRANSPARENT, Palette.RADIUS_SMALL))


static func _style_containers(theme: Theme) -> void:
	theme.set_constant("separation", "VBoxContainer", Palette.GAP)
	theme.set_constant("separation", "HBoxContainer", Palette.GAP)
	theme.set_constant("h_separation", "GridContainer", Palette.GAP)
	theme.set_constant("v_separation", "GridContainer", Palette.GAP)
	theme.set_constant("margin_left", "MarginContainer", Palette.PAD)
	theme.set_constant("margin_right", "MarginContainer", Palette.PAD)
	theme.set_constant("margin_top", "MarginContainer", Palette.PAD)
	theme.set_constant("margin_bottom", "MarginContainer", Palette.PAD)
