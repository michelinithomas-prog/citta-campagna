extends TestCase
## Le reliquie: bonus che valgono per tutta la partita, comprati in bottega o
## guadagnati agli incontri.
##
## I test qui sotto **non nominano quasi mai una reliquia**. Chiedono ai dati chi
## ha una certa chiave e provano quella: i nomi cambiano — è già successo, tutti
## e diciotto in un colpo — e un test che parla di meccanica non deve diventare
## rosso perché una reliquia ha cambiato nome.

var run: RunState
var market: Market


func before_each() -> void:
	run = RunState.new(RngStream.new(5))
	market = Market.new(RngStream.new(5))
	market.roll(1, run)


func after_each() -> void:
	run = null
	market = null


## La prima reliquia che ha quella chiave. Vuota se nessuna ce l'ha — e in quel
## caso il test lo dice invece di passare in silenzio.
func _con(chiave: String) -> Dictionary:
	for relic in Content.list("relics"):
		if relic.has(chiave):
			return relic
	return {}


## Come sopra, ma dentro la `rule`: serve a trovare chi tocca le carte.
func _con_regola(chiave: String) -> Dictionary:
	for relic in Content.list("relics"):
		var rule: Dictionary = relic.get("rule", {})
		if rule.has(chiave):
			return relic
	return {}


# --- effetti una tantum --------------------------------------------------

func test_una_reliquia_di_vita_alza_il_massimo() -> void:
	var relic := _con("max_hp_add")
	assert_false(relic.is_empty(), "nessuna reliquia tocca la vita massima")

	var prima := run.max_hp
	assert_true(run.add_relic(relic))
	assert_eq(run.max_hp, maxi(prima + int(relic["max_hp_add"]), 10))


func test_una_reliquia_di_vite_ne_regala_qualcuna() -> void:
	var relic := _con("lives_add")
	assert_false(relic.is_empty(), "nessuna reliquia regala vite")

	var prima := run.lives
	run.add_relic(relic)
	assert_eq(run.lives, prima + int(relic["lives_add"]))


func test_una_reliquia_di_carte_ingrossa_il_mazzo() -> void:
	var relic := _con("cards_add")
	assert_false(relic.is_empty(), "nessuna reliquia porta carte")

	var prima := run.deck_size()
	run.add_relic(relic, RngStream.new(9))
	assert_eq(run.deck_size(), prima + int(relic["cards_add"]))


func test_un_deckbox_porta_carte_del_suo_mazzo_e_basta() -> void:
	var relic := _con("cards_family")
	assert_false(relic.is_empty(), "nessun deckbox nei dati")

	var famiglia := String(relic["cards_family"])
	var prima := run.deck_size()
	run.add_relic(relic, RngStream.new(9))

	var arrivate := run.collection.slice(prima)
	assert_eq(arrivate.size(), int(relic["cards_add"]))
	for card in arrivate:
		assert_eq(card.family, famiglia, "%s ha portato una carta di %s" % [relic["name"], card.family])


func test_la_stessa_reliquia_non_si_compra_due_volte() -> void:
	var relic := _con("max_hp_add")
	assert_true(run.add_relic(relic))
	assert_false(run.add_relic(relic), "una reliquia si prende una volta sola")


# --- effetti a lettura continua ------------------------------------------

func test_una_reliquia_puo_allargare_la_plancia() -> void:
	var relic := _con("board_add")
	assert_false(relic.is_empty(), "nessuna reliquia allarga la plancia")
	run.add_relic(relic)
	assert_eq(run.board_bonus(), int(relic["board_add"]))


func test_una_reliquia_puo_fruttare_a_ogni_round() -> void:
	var relic := _con("gold_per_round_add")
	assert_false(relic.is_empty(), "nessuna reliquia frutta oro")
	run.add_relic(relic)
	assert_eq(run.extra_gold_per_round(), int(relic["gold_per_round_add"]))


func test_una_reliquia_puo_dare_scudo_in_partenza() -> void:
	var relic := _con("start_shield")
	assert_false(relic.is_empty(), "nessuna reliquia dà scudo in partenza")
	run.add_relic(relic)
	assert_eq(run.start_shield(), int(relic["start_shield"]))


func test_una_reliquia_puo_scontare_tutto() -> void:
	var relic := _con("price_mult")
	assert_false(relic.is_empty(), "nessuna reliquia sconta")

	var card := CardLibrary.build("picche_c7")
	var prima := market.card_price(card)
	run.add_relic(relic)
	market.roll(1, run)
	assert_lt(market.card_price(card), prima, "le carte devono costare meno")


func test_una_reliquia_puo_indurirti_contro_veleno_e_sangue() -> void:
	var relic := _con("status_resist")
	assert_false(relic.is_empty(), "nessuna reliquia protegge dagli stati")
	run.add_relic(relic)

	var quanto := run.status_resist()
	assert_gt(quanto, 0)

	var side := Side.new("io", [], RngStream.new(1), {"hp": 50, "status_resist": quanto})
	side.apply_poison(quanto + 2)
	assert_eq(side.poison, 2, "il fegato deve scrollarne via una parte")
	side.apply_poison(quanto)
	assert_eq(side.poison, 2, "e una dose che non lo supera non deve arrivare affatto")


func test_una_reliquia_puo_far_partire_la_catena_gia_avviata() -> void:
	var relic := _con("start_combo")
	assert_false(relic.is_empty(), "nessuna reliquia avvia la catena")
	run.add_relic(relic)

	var quanto := run.start_combo()
	assert_gt(quanto, 0)
	var side := Side.new("io", [], RngStream.new(1), {"hp": 50, "combo": quanto})
	assert_eq(side.combo, quanto)
	assert_gt(side.combo_multiplier(), 1.0)


# --- le regole sulle carte -----------------------------------------------

func test_una_regola_di_famiglia_tocca_solo_la_sua_famiglia() -> void:
	var relic := _con_regola("family")
	assert_false(relic.is_empty(), "nessuna reliquia parla a una famiglia sola")

	var famiglia := String(relic["rule"]["family"])
	run.add_relic(relic)

	var deck := run.battle_deck()
	for i in run.collection.size():
		var originale := run.collection[i]
		if originale.family == famiglia:
			continue
		assert_eq(deck[i].value(), originale.value(),
			"%s ha toccato %s, che è di %s" % [relic["name"], deck[i].id, deck[i].family])
		assert_almost(deck[i].interval(), originale.interval(), 0.001,
			"%s ha cambiato il ritmo a %s" % [relic["name"], deck[i].id])


func test_una_regola_di_tag_tocca_solo_le_carte_che_lo_portano() -> void:
	var relic := _con_regola("tag")
	assert_false(relic.is_empty(), "nessuna reliquia parla per tag")

	var tag := String(relic["rule"]["tag"])
	run.add_relic(relic)

	var deck := run.battle_deck()
	for i in run.collection.size():
		var originale := run.collection[i]
		if originale.has_tag(tag):
			continue
		assert_eq(deck[i].value(), originale.value(),
			"%s ha toccato %s, che non è %s" % [relic["name"], deck[i].id, tag])


func test_una_soglia_di_valore_lascia_stare_le_altre() -> void:
	var relic := _con_regola("value_max")
	if relic.is_empty():
		relic = _con_regola("value_min")
	if relic.is_empty():
		return  # nessuna reliquia a soglia, niente da verificare

	var rule: Dictionary = relic["rule"]
	run.add_relic(relic)

	var deck := run.battle_deck()
	for i in run.collection.size():
		var nudo := run.collection[i].stats.get_base("value")
		var dentro := true
		if rule.has("value_min") and nudo < float(rule["value_min"]):
			dentro = false
		if rule.has("value_max") and nudo > float(rule["value_max"]):
			dentro = false
		if dentro:
			continue
		assert_eq(deck[i].value(), run.collection[i].value(),
			"%s ha toccato %s, che è fuori soglia" % [relic["name"], deck[i].id])


# --- integrità dei dati --------------------------------------------------

func test_ogni_reliquia_fa_qualcosa_e_ha_un_prezzo() -> void:
	const CHIAVI_CHE_FANNO := [
		"max_hp_add", "lives_add", "cards_add", "board_add", "gold_per_round_add",
		"start_shield", "price_mult", "status_resist", "start_combo", "rule",
	]
	for relic in Content.list("relics"):
		var id := String(relic.get("id", ""))
		assert_gt(int(relic.get("cost", 0)), 0, "%s non ha un prezzo" % id)
		assert_false(String(relic.get("text", "")).is_empty(), "%s non spiega cosa fa" % id)

		var fa_qualcosa := false
		for chiave in CHIAVI_CHE_FANNO:
			if relic.has(chiave):
				fa_qualcosa = true
		assert_true(fa_qualcosa, "%s non fa niente" % id)


func test_una_reliquia_comprata_non_torna_in_vetrina() -> void:
	market.roll(3, run)
	if market.relic_offers.is_empty():
		return
	var presa: Dictionary = market.relic_offers[0]
	run.add_relic(presa)

	for giro in 8:
		market.roll(3 + giro, run)
		for offerta in market.relic_offers:
			assert_ne(String(offerta.get("id", "")), String(presa.get("id", "")),
				"%s è già in tasca e la vetrina la rimette in vendita" % presa.get("name"))


func test_le_reliquie_degli_incontri_non_stanno_in_vetrina() -> void:
	for giro in 12:
		market.roll(giro + 1, run)
		for offerta in market.relic_offers:
			assert_true(bool(offerta.get("in_shop", true)),
				"%s si guadagna solo agli incontri, non si vende" % offerta.get("name"))
