extends SceneTree
## Racconta cosa succede davvero a un giocatore medio, round per round.
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/diagnosi_economia.gd
##
## Serve quando balance_test diventa rosso: dice *dove* la run si rompe, invece
## di limitarsi a dire che si rompe.

var _lib: GDScript
var _run_cls: GDScript
var _market_cls: GDScript
var _side_cls: GDScript
var _duel_cls: GDScript


func _initialize() -> void:
	_lib = load("res://game/logic/card_library.gd")
	_run_cls = load("res://game/logic/run_state.gd")
	_market_cls = load("res://game/logic/market.gd")
	_side_cls = load("res://game/logic/side.gd")
	_duel_cls = load("res://game/logic/duel.gd")


func _process(_delta: float) -> bool:
	var cfg := root.get_node("Cfg")
	var content := root.get_node("Content")

	print("=== PREZZI SUI DATI VERI ===")
	var rng: Object = load("res://core/sim/rng_stream.gd").new(1)
	var run: Object = _run_cls.new(rng)
	var market: Object = _market_cls.new(rng)
	market.roll(1, run)

	var somma := 0.0
	var quante := 0
	for id in _lib.pool_ids():
		var card: Object = _lib.build(id)
		if card != null:
			somma += market.card_price(card)
			quante += 1
	print("  carta media:   %.2f oro (su %d carte)" % [somma / quante, quante])

	var s := 0.0
	for seal in content.list("seals"):
		s += market.seal_price(seal)
	print("  innesto medio: %.2f oro" % (s / content.list("seals").size()))

	var r := 0.0
	for relic in content.list("relics"):
		r += market.relic_price(relic)
	print("  reliquia media: %.2f oro" % (r / content.list("relics").size()))
	print("  oro per round: %d   iniziale: %d   bonus vittoria: %d" % [
		cfg.get_int("shop.gold_per_round", 0), cfg.get_int("shop.starting_gold", 0),
		cfg.get_int("shop.win_bonus", 0)])

	print("\n=== DODICI RUN, ROUND PER ROUND ===")
	var vinte := 0
	for seed_value in range(1, 13):
		var esito := _gioca(seed_value)
		if esito["vinta"]:
			vinte += 1
		print("  seed %2d: arrivato al round %d, %s (mazzo %d, oro avanzato %d) — %s" % [
			seed_value, esito["round"], "VINTA" if esito["vinta"] else "persa",
			esito["carte"], esito["oro"], esito["storia"]])
	print("\n  vinte: %d su 12" % vinte)
	quit(0)
	return true


func _gioca(seed_value: int) -> Dictionary:
	var rng: Object = load("res://core/sim/rng_stream.gd").new(seed_value)
	var run: Object = _run_cls.new(rng)
	var market: Object = _market_cls.new(rng)
	var storia: Array[String] = []
	var vinta := false

	while true:
		market.roll(run.round_number, run)
		var comprate := _compra(market, run)

		var recipe: Dictionary = run.opponent_for_round()
		var slots: int = root.get_node("Cfg").get_int("player.board_size", 5)
		var mine: Object = _side_cls.new("io", run.battle_deck(), rng, {
			"hp": run.max_hp, "board_size": slots + run.board_bonus(),
			"shield": run.start_shield(), "is_player": true})
		var theirs: Object = _side_cls.new(String(recipe.get("name", "")),
			_lib.generate(rng, recipe), rng,
			{"hp": int(recipe.get("hp", 40)), "shield": int(recipe.get("shield", 0)),
			 "board_size": slots})

		var duel: Object = _duel_cls.new(mine, theirs, rng, 0.05)
		duel.simulate_to_end()
		storia.append("r%d:%s%s" % [run.round_number, "V" if duel.won else "P", comprate])
		run.earn(mine.gold())
		run.evolvi(duel.evoluzioni)  # come in partita: la crescita resta
		vinta = duel.won
		duel.resolver.clear_handlers()

		if not run.finish_round(vinta):
			break

	return {"vinta": run.victory, "round": run.round_number, "carte": run.deck_size(),
			"oro": run.gold(), "storia": " ".join(storia)}


## Compra come il giocatore finto di balance_test: prima una reliquia se se la
## permette, poi le carte più care alla sua portata.
func _compra(market: Object, run: Object) -> String:
	var presi := ""
	for i in market.relic_offers.size():
		if market.relic_price(market.relic_offers[i]) <= run.gold():
			market.buy_relic(i, run)
			presi += "R"
			break

	var quante := 0
	while quante < 4:
		var migliore := -1
		var prezzo := 0
		for i in market.card_offers.size():
			var costo: int = market.card_price(market.card_offers[i])
			if costo <= run.gold() and costo > prezzo:
				migliore = i
				prezzo = costo
		if migliore < 0 or market.buy_card(migliore, run) == null:
			break
		quante += 1
		presi += "c"
	return "(%s)" % presi if presi != "" else ""
