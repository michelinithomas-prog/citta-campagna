extends SceneTree
## Quanto è fluida la battaglia, misurata sull'orologio vero.
##
##   godot --path templates/cittacampagna \
##         --script res://tools/misura_fluidita.gd -- [round] [seed] [secondi]
##
## **Senza `--fixed-fps`**: qui serve il tempo vero, non quello di comodo che
## si usa per registrare le clip. Con `--fixed-fps` ogni fotogramma varrebbe
## 1/60 per definizione e la misura direbbe sempre che va tutto bene.
##
## Riporta la distribuzione, non la media: una media di 60 fps con un fotogramma
## su venti da 120 ms è esattamente ciò che si vede «a scatti», e la media da
## sola non lo dice. I percentili sì.

var play: Node
var _frames := 0
var _secondi := 12.0
var _round := 9
var _seed := 4242
var _tempi: Array[float] = []
var _partito := false
var _ultimo_ms := 0
var _ultime_barre := ""
var _cambi_barre := 0
var _ticks := 0
var _ultimo_tick := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_round = int(args[0])
	if args.size() >= 2:
		_seed = int(args[1])
	if args.size() >= 3:
		_secondi = float(args[2])

	root.get_node("Rng").new_run(_seed)
	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play


func _process(delta: float) -> bool:
	_frames += 1

	if _frames == 5:
		while play.run.round_number < _round:
			play.run.finish_round(true)
		play._start_battle()

	# Si misura dalla prima carta che parte: prima c'è un tavolo fermo, e il
	# tavolo fermo è fluido per chiunque.
	if not _partito and play.duel != null and play.duel.activations > 0:
		_partito = true
		_ultimo_ms = Time.get_ticks_usec()
		return false

	if _partito:
		var ora := Time.get_ticks_usec()
		_tempi.append(float(ora - _ultimo_ms) / 1000.0)
		_ultimo_ms = ora

		# Renderizzare 120 volte al secondo non serve a niente se quello che si
		# disegna cambia venti volte al secondo. Qui si contano i CAMBIAMENTI,
		# non i fotogrammi: è la differenza fra fluido e a scatti.
		# Si guarda il valore DISEGNATO, non quello del modello: il modello
		# cambia a ogni tick per definizione, ed è la vista che deve muoversi
		# alla velocità dello schermo.
		var barre := ""
		for lato in play._views:
			for vista in play._views[lato]:
				barre += "%.5f|" % vista._timer.value
		if barre != _ultime_barre:
			_cambi_barre += 1
			_ultime_barre = barre
		if play.duel != null:
			if play.duel.clock.tick_count != _ultimo_tick:
				_ticks += 1
				_ultimo_tick = play.duel.clock.tick_count

	if _partito and _tempi.size() > 0:
		var totale := 0.0
		for t in _tempi:
			totale += t
		if totale > _secondi * 1000.0 or (play.duel != null and play.duel.is_over):
			_referto()
			return true

	if _frames > 60000:
		print("la battaglia non è mai partita")
		quit(1)
		return true
	return false


func _percentile(ordinati: Array[float], q: float) -> float:
	if ordinati.is_empty():
		return 0.0
	return ordinati[clampi(int(q * ordinati.size()), 0, ordinati.size() - 1)]


func _referto() -> void:
	var ordinati := _tempi.duplicate()
	ordinati.sort()
	var totale := 0.0
	for t in _tempi:
		totale += t
	var media := totale / _tempi.size()

	print("fotogrammi misurati: %d in %.1f s" % [_tempi.size(), totale / 1000.0])
	print("")
	print("  media      %6.2f ms   (%.0f al secondo)" % [media, 1000.0 / maxf(media, 0.01)])
	print("  mediana    %6.2f ms" % _percentile(ordinati, 0.50))
	print("  95° perc.  %6.2f ms" % _percentile(ordinati, 0.95))
	print("  99° perc.  %6.2f ms" % _percentile(ordinati, 0.99))
	print("  il peggiore %5.2f ms" % ordinati[-1])
	print("")

	# A 60 fps un fotogramma dura 16,7 ms. Sopra i 33 se ne è saltato uno, e
	# saltarne uno ogni tanto è precisamente ciò che si vede «a scatti».
	var saltati := 0
	var molto := 0
	for t in _tempi:
		if t > 33.0:
			saltati += 1
		if t > 100.0:
			molto += 1
	print("  fotogrammi oltre 33 ms (uno saltato):  %d  (%.1f%%)" % [
		saltati, 100.0 * saltati / _tempi.size()])
	print("  fotogrammi oltre 100 ms (scatto vero): %d  (%.1f%%)" % [
		molto, 100.0 * molto / _tempi.size()])
	print("")
	var secondi := totale / 1000.0
	print("QUANTE VOLTE AL SECONDO CAMBIA QUELLO CHE SI VEDE")
	print("  fotogrammi disegnati:        %6.1f al secondo" % (_tempi.size() / secondi))
	print("  tick della simulazione:      %6.1f al secondo" % (_ticks / secondi))
	print("  cambi delle BARRE DISEGNATE:  %6.1f al secondo" % (_cambi_barre / secondi))
	print("")
	print("  → si ridisegna %.1f volte per ogni cambiamento vero" % (
		float(_tempi.size()) / maxf(_cambi_barre, 1)))
	quit(0)
