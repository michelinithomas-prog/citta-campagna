extends Control
## Menu principale, uguale per tutti i template.
##
## Titolo e sottotitolo non sono scritti qui: arrivano dal nome del progetto e
## da tuning.json, così questo file non si tocca mai.
##
##   {"menu": {"subtitle": "un deckbuilder da jam", "best_label": "Record"}}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())

	var game_name := String(ProjectSettings.get_setting("application/config/name", "Gioco"))
	var subtitle := String(Cfg.get_value("menu.subtitle", ""))

	var column := Ui.vbox([], Palette.PAD)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = 280

	var title := Ui.title(game_name)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	if not subtitle.is_empty():
		var subtitle_label := Ui.dim(subtitle, Palette.FONT_BODY)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(subtitle_label)

	column.add_child(_best_score_label())
	column.add_child(Ui.spacer(Palette.PAD))
	column.add_child(Ui.button("Gioca", func() -> void: Router.start_new_run()))
	column.add_child(_settings_section())

	if not OS.has_feature("web"):
		column.add_child(Ui.button("Esci", func() -> void: get_tree().quit()))

	add_child(Ui.center(column))

	var menu_music := String(Cfg.get_value("audio.menu_music", ""))
	if not menu_music.is_empty():
		Audio.music(menu_music)


func _best_score_label() -> Control:
	var key := String(Cfg.get_value("menu.best_key", "score"))
	var best: float = float(Save.get_value("best." + key, 0.0))
	if best <= 0.0:
		return Ui.spacer(0)

	var text := "%s: %s" % [Cfg.get_value("menu.best_label", "Record"), _format_number(best)]
	var node := Ui.label(text, Palette.FONT_BODY, Palette.GOLD)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


## Pannello volumi, aperto/chiuso da un pulsante.
func _settings_section() -> Control:
	var sliders := Ui.vbox([], Palette.PAD_SMALL)
	sliders.visible = false
	for bus in [["master", "Generale"], ["music", "Musica"], ["sfx", "Effetti"]]:
		sliders.add_child(_volume_row(bus[0], bus[1]))

	var toggle := Ui.button("Audio", func() -> void: sliders.visible = not sliders.visible)
	return Ui.vbox([toggle, sliders], Palette.PAD_SMALL)


func _volume_row(bus: String, label_text: String) -> Control:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Audio.get_volume(bus)
	slider.custom_minimum_size.x = 140
	slider.value_changed.connect(func(value: float) -> void: Audio.set_volume(bus, value))

	var row := Ui.hbox([Ui.dim(label_text), Ui.spacer(), slider])
	return row


func _format_number(value: float) -> String:
	if value >= 1000.0:
		return "%.1fk" % (value / 1000.0)
	return str(int(value))
