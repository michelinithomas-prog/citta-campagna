extends SceneTree
## Prova il giro completo di "Continua": si gioca qualche round, si esce, si
## rientra dal menu e si deve ritrovare la partita dov'era.
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/repro_continua.gd -- [round_da_giocare]
##
## È la prova che i test unitari non possono fare: il salvataggio funziona in
## isolamento, ma "Continua" passa dal menu, da una bandiera e da una scena
## ricaricata da capo. Il difetto di questa catena è stato proprio lì in mezzo —
## il menu non alzava la bandiera e la partita ripartiva da zero.

var play: Node
var _frames := 0
var _fase := 0
var _obiettivo := 3
var _errori := 0
var _prima := {}
var _save: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_obiettivo = maxi(int(args[0]), 2)
	_save = root.get_node("Save")
	root.get_node("Rng").new_run(4242)

	# Si parte pulito: niente partita di ieri a confondere le idee.
	root.get_node("Content").reload()
	_avvia_scena()


func _avvia_scena() -> void:
	if play != null and is_instance_valid(play):
		play.queue_free()
	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	# Questo strumento punta a una schermata precisa: i dialoghi li salta.
	# L'introduzione da sola sono centoventi battute, e non è quello che
	# sta misurando.
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 25 != 0:
		return false

	match _fase:
		0:
			# Si gioca fino al round obiettivo, comprando qualcosa per strada.
			if play.run.round_number < _obiettivo:
				play.run.earn(60)
				if not play.market.card_offers.is_empty():
					play._on_buy_card(0)
				if not play.market.relic_offers.is_empty():
					play._on_buy_relic(0)
				play._start_battle()
				play.duel.simulate_to_end()
				return false
			_prima = _fotografia()
			print("[PRIMA]  %s" % _prima)
			_fase = 1
		1:
			# Si "esce dal gioco": la scena muore, ma il salvataggio resta.
			play.queue_free()
			play = null
			print("[USCITA] partita chiusa; salvata sul disco: %s" % _save.has("run"))
			if not _save.has("run"):
				print("   ✗ non c'è nessun salvataggio da riprendere")
				_errori += 1
			_fase = 2
		2:
			# Si rientra da "Continua": è il menu ad alzare questa bandiera.
			_save.set_value("options.resume", true)
			_save.flush()
			_avvia_scena()
			_fase = 3
		3:
			var dopo := _fotografia()
			print("[DOPO]   %s" % dopo)
			for chiave in _prima:
				if _prima[chiave] != dopo.get(chiave):
					print("   ✗ %s: era %s, ora %s" % [chiave, _prima[chiave], dopo.get(chiave)])
					_errori += 1
			if _errori == 0:
				print("\nLA PARTITA È RIPRESA DOV'ERA")
			else:
				print("\n%d DIFFERENZE: \"Continua\" non riprende la partita" % _errori)
			quit(0 if _errori == 0 else 1)
			return true
	return false


func _fotografia() -> Dictionary:
	return {
		"round": play.run.round_number,
		"vite": play.run.lives,
		"oro": play.run.gold(),
		"vita_max": play.run.max_hp,
		"carte": play.run.deck_size(),
		"reliquie": play.run.relics.size(),
	}
