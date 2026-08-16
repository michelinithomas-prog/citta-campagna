extends Control
## Schermata di fine partita, uguale per tutti i template.
##
## Le statistiche arrivano da Router.game_over(vinto, {...}): ogni chiave del
## dizionario diventa una riga. Le chiavi si presentano già leggibili
## ("Round raggiunto": 7), non serve mappare niente qui.
##
## La chiave indicata in tuning.json come menu.best_key viene confrontata con
## il record salvato e, se migliore, celebrata.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())

	var won := Router.last_run_won
	var stats := Router.last_run_stats

	var column := Ui.vbox([], Palette.PAD)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = 300

	var heading := Ui.title("Vittoria" if won else "Sconfitta")
	heading.add_theme_color_override("font_color", Palette.SUCCESS if won else Palette.DANGER)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	for key in stats:
		column.add_child(_stat_row(String(key), stats[key]))

	var record_label := _record_label(stats)
	if record_label != null:
		column.add_child(record_label)

	column.add_child(Ui.spacer(Palette.PAD))
	column.add_child(Ui.button("Gioca ancora", func() -> void: Router.start_new_run()))
	column.add_child(Ui.button("Menu principale", func() -> void: Router.goto("menu")))

	var seed_label := Ui.label("seed %d" % Rng.seed_value, Palette.FONT_SMALL, Palette.TEXT_MUTED)
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(seed_label)

	add_child(Ui.center(column))


func _stat_row(key: String, value: Variant) -> Control:
	return Ui.hbox([Ui.dim(key, Palette.FONT_BODY), Ui.spacer(), Ui.label(str(value))])


## Salva e celebra il nuovo record, se c'è.
func _record_label(stats: Dictionary) -> Control:
	var best_key := String(Cfg.get_value("menu.best_key", "score"))
	var stat_key := String(Cfg.get_value("menu.best_stat", ""))
	if stat_key.is_empty() or not stats.has(stat_key):
		return null

	var value := float(stats[stat_key])
	if not Save.record_best(best_key, value):
		return null

	Audio.sfx("level_up")
	var node := Ui.label("Nuovo record!", Palette.FONT_BODY, Palette.GOLD)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node
