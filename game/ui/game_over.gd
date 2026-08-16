extends Control
## Schermata di fine partita, nei colori di questo gioco.
##
## È un fork di `core/ui/game_over.gd`: la logica è la stessa (le statistiche
## arrivano da `Router.game_over(vinto, {...})`, ogni chiave diventa una riga, e
## il record si confronta con `menu.best_key`), cambia solo il vestito. Sta qui e
## non nel core perché `core/` è symlinkato in tutti e cinque i template.
##
## È la schermata che il giocatore vede a ogni morte: lasciarla grigia mentre il
## resto è legno e ottone si nota subito.

## Le tre schermate: si vince, si perde, oppure si molla tutto e si va via con
## lei. Il nome lo lascia scritto `play.gd` in `RunState.CHIAVE_FINALE`.
const FINALI := "res://game/art/finali/%s.png"

## Quanto buio va sopra l'illustrazione. Poco: le tre immagini hanno già il loro
## titolo dipinto sopra, e questo velo serve solo a far staccare il riquadro dei
## numeri — non a spegnere il disegno che il giocatore si è appena guadagnato.
const VELO := 0.28


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Hud.tema()
	add_child(Ui.background(Hud.LEGNO_SCURO))

	var won := Router.last_run_won
	var stats := Router.last_run_stats
	var illustrato := _costruisci_illustrazione()

	var column := Ui.vbox([], Hud.PAD_SMALL)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = 340

	# Il titolo si scrive solo se non c'è il disegno: quando c'è, "VITTORIA!" è
	# già dipinto grande in cima, e ripeterlo sotto sarebbe la stessa parola due
	# volte nella stessa schermata.
	if not illustrato:
		var heading := Ui.label("Vittoria" if won else "Sconfitta", Hud.TESTO_TITOLO,
			Hud.CURA if won else Hud.DANNO)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(heading)
		column.add_child(Ui.spacer(Hud.PAD_SMALL))

	for key in stats:
		column.add_child(_stat_row(String(key), stats[key]))

	var record_label := _record_label(stats)
	if record_label != null:
		column.add_child(record_label)

	column.add_child(Ui.spacer(Hud.PAD_SMALL))
	column.add_child(Ui.button("Gioca ancora", func() -> void:
		RunState.clear_save()
		Router.start_new_run()
	))
	column.add_child(Ui.button("Menu principale", func() -> void: Router.goto("menu")))

	var seed_label := Ui.label(tr("seed %d") % Rng.seed_value, Hud.TESTO_PICCOLO, Hud.CREMA_MUTED)
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(seed_label)

	var riquadro := Hud.cornice(Ui.margin(column, Hud.PAD))
	if not illustrato:
		add_child(Ui.center(riquadro))
		return

	# Con l'illustrazione il riquadro scende in basso a destra: al centro ci sono
	# le facce, ed è quello che si è venuti a vedere.
	var fondo := Ui.hbox([Ui.spacer(), riquadro], 0)
	fondo.alignment = BoxContainer.ALIGNMENT_END
	var colonna := Ui.vbox([Ui.spacer(), fondo], 0)
	colonna.alignment = BoxContainer.ALIGNMENT_END
	add_child(Ui.fullscreen(Ui.margin(colonna, Hud.PAD)))


## L'illustrazione del finale, se ce n'è una. Falso quando manca: la schermata
## torna quella scritta di sempre, senza saltare per aria.
func _costruisci_illustrazione() -> bool:
	var percorso := FINALI % String(Save.get_value(RunState.CHIAVE_FINALE, "sconfitta"))
	if not ResourceLoader.exists(percorso):
		return false

	var disegno := TextureRect.new()
	disegno.texture = load(percorso)
	disegno.set_anchors_preset(Control.PRESET_FULL_RECT)
	disegno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disegno.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disegno.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(disegno)

	var velo := Ui.background(Hud.INCHIOSTRO)
	velo.color.a = VELO
	add_child(velo)
	return true


## Le chiavi del riepilogo fanno due mestieri: **indicizzano** — `menu.best_stat`
## arriva da `tuning.json` e ritrova il valore del record dentro il dizionario di
## `RunState.stats()` — e **si mostrano**. Per questo nel dizionario restano
## italiane e la traduzione sta qui: questo è l'unico punto in cui smettono di
## essere una chiave e diventano un'etichetta. Tradurle a monte farebbe sparire
## il record senza un errore.
func _stat_row(key: String, value: Variant) -> Control:
	return Ui.hbox([
		Ui.dim(tr(key), Hud.TESTO),
		Ui.spacer(),
		Ui.label(str(value), Hud.TESTO, Hud.CREMA),
	])


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
	var node := Ui.label("Nuovo record!", Hud.TESTO, Hud.ORO)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node
