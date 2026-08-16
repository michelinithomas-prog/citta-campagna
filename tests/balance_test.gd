extends TestCase
## Il bilanciamento della run intera, non della singola battaglia.
##
## Simula partite complete con un giocatore finto che compra sempre la carta più
## cara che si può permettere. Non è un bravo giocatore — è una linea di base: se
## nemmeno lui arriva mai in fondo il gioco è ingiocabile, se arriva sempre non
## c'è niente da imparare.
##
## Quando ritocchi i numeri in tuning.json, è questo il test da guardare.


## Gioca una run intera e racconta com'è andata.
func _simula_run(seed_value: int) -> Dictionary:
	var rng := RngStream.new(seed_value)
	var run := RunState.new(rng)
	var market := Market.new(rng)
	var ragioni := {}
	var vinta := false

	while true:
		market.roll(run.round_number, run)
		_compra_quello_che_puo(market, run)

		var recipe := run.opponent_for_round()
		var slots := Cfg.get_int("player.board_size", 5)
		var mine := Side.new("io", run.battle_deck(), rng,
			{"hp": run.max_hp, "board_size": slots, "is_player": true})
		# `ricetta_svelata` come in partita: nelle prime due sfide l'avversario
		# non gioca One né Gaiofanamon, esattamente come il giocatore non può
		# comprarli. Simulare un avversario con carte che il giocatore non ha
		# ancora visto misurerebbe un gioco che non esiste.
		var theirs := Side.new(String(recipe.get("name", "")),
			CardLibrary.generate(rng, run.ricetta_svelata(recipe)), rng,
			{"hp": int(recipe.get("hp", 40)), "shield": int(recipe.get("shield", 0)), "board_size": slots})

		var duel := Duel.new(mine, theirs, rng, 0.05)
		duel.simulate_to_end()
		ragioni[duel.reason] = int(ragioni.get(duel.reason, 0)) + 1
		run.earn(mine.gold())
		# Come in partita: le creature cresciute restano cresciute. Senza questa
		# riga il simulatore misurerebbe un gioco in cui i gaiofanamon non
		# scalano mai — cioè un gioco diverso da quello che si gioca.
		run.evolvi(duel.evoluzioni)
		vinta = duel.won
		duel.resolver.clear_handlers()

		if not run.finish_round(vinta):
			break

	return {
		"vinta": vinta and run.lives > 0,
		"round": run.round_number,
		"vite": run.lives,
		"carte": run.deck_size(),
		"ragioni": ragioni,
	}


## Il giocatore finto: prende la prima reliquia che si può permettere — valgono
## per tutta la partita, un giocatore vero le compra — e poi spende quello che
## resta nella carta più cara alla sua portata. Nessuna strategia, nessuna
## sinergia: è una linea di base, non un campione.
func _compra_quello_che_puo(market: Market, run: RunState) -> void:
	for i in market.relic_offers.size():
		if market.relic_price(market.relic_offers[i]) <= run.gold():
			market.buy_relic(i, run)
			break

	var comprate := 0
	while comprate < 4:
		var migliore := -1
		var prezzo := 0
		for i in market.card_offers.size():
			var costo := market.card_price(market.card_offers[i])
			if costo <= run.gold() and costo > prezzo:
				migliore = i
				prezzo = costo
		if migliore < 0 or market.buy_card(migliore, run) == null:
			return
		comprate += 1


func test_una_run_si_puo_portare_a_casa_ma_non_e_regalata() -> void:
	var vinte := 0
	var arrivo := 0
	var ragioni := {}

	for seed_value in range(1, 13):
		var esito := _simula_run(seed_value)
		if esito["vinta"]:
			vinte += 1
		arrivo += int(esito["round"])
		for reason in esito["ragioni"]:
			ragioni[reason] = int(ragioni.get(reason, 0)) + int(esito["ragioni"][reason])

	assert_gt(vinte, 0, "nessuna run vinta su 12: il gioco è ingiocabile")
	assert_lt(vinte, 12, "vinte tutte e 12: non c'è niente da imparare")
	assert_true(ragioni.has(Side.REASON_HP), "in dodici run nessuno è mai morto di ferite: %s" % ragioni)
	assert_true(ragioni.has(Side.REASON_DECKOUT), "in dodici run nessuno è mai rimasto senza carte: %s" % ragioni)


func test_la_run_non_si_ferma_al_primo_round() -> void:
	# Se un giocatore qualunque perde subito, la curva parte troppo ripida.
	var oltre := 0
	for seed_value in range(1, 9):
		if int(_simula_run(seed_value)["round"]) > 2:
			oltre += 1
	assert_gt(oltre, 5, "solo %d run su 8 sono andate oltre il secondo round" % oltre)


func test_il_mazzo_cresce_durante_la_run() -> void:
	# Se l'oro non basta mai a comprare niente, la bottega è finta.
	var esito := _simula_run(4)
	assert_gt(int(esito["carte"]), (Cfg.get_value("deck.starting", []) as Array).size(),
		"il giocatore non è riuscito a comprare nemmeno una carta")
