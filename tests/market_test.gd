extends TestCase
## La bottega: prezzi, acquisti, sigilli, rimozioni.

var run: RunState
var market: Market


func before_each() -> void:
	run = RunState.new(RngStream.new(5))
	market = Market.new(RngStream.new(5))
	market.roll(1)


func after_each() -> void:
	run = null
	market = null


# --- vetrina -------------------------------------------------------------

func test_la_vetrina_ha_il_numero_di_offerte_previsto() -> void:
	assert_eq(market.card_offers.size(), Cfg.get_int("shop.card_offers", 3))
	assert_eq(market.seal_offers.size(), Cfg.get_int("shop.seal_offers", 2))


func test_nella_vetrina_non_esce_due_volte_la_stessa_cosa() -> void:
	# Vedere lo stesso innesto due volte di fianco sembra un bug anche quando è
	# solo sfortuna. Vale per tutte e tre le vetrine.
	for giro in 12:
		market.roll(giro + 1, run)
		for elenco in [market.seal_offers, market.relic_offers]:
			var visti := {}
			for voce in elenco:
				var id := String(voce.get("id", ""))
				assert_false(visti.has(id), "%s compare due volte nella stessa vetrina" % id)
				visti[id] = true


func test_la_vetrina_e_riproducibile() -> void:
	var altro := Market.new(RngStream.new(5))
	altro.roll(1)
	for i in market.card_offers.size():
		assert_eq(altro.card_offers[i].id, market.card_offers[i].id)


func test_ai_primi_round_non_escono_le_figure() -> void:
	for i in market.card_offers.size():
		assert_lt(market.card_offers[i].value(), 5, "al round 1 il tetto è 4")


func test_il_rimescolo_costa_e_cambia_la_vetrina() -> void:
	var prima := market.card_offers[0].id
	var oro := run.gold()
	assert_true(market.reroll(run, 1))
	assert_eq(run.gold(), oro - market.reroll_price())
	assert_ne(market.card_offers[0].id, prima)


func test_senza_oro_non_si_rimescola() -> void:
	run.wallet.set_amount(RunState.GOLD, 0.0)
	assert_false(market.reroll(run, 1))


# --- prezzi --------------------------------------------------------------

func test_i_mazzi_lenti_costano_piu_dei_veloci_a_parita_di_valore() -> void:
	# È il numero che tiene in piedi l'equilibrio fra le due famiglie: una carta
	# lenta consuma meno mazzo, quindi vale di più e deve costare di più.
	var citta := CardLibrary.build("picche_c5")
	var campagna := CardLibrary.build("spade_r5")
	assert_gt(market.card_price(campagna), market.card_price(citta))


func test_il_prezzo_cresce_col_valore() -> void:
	assert_gt(
		market.card_price(CardLibrary.build("picche_c13")),
		market.card_price(CardLibrary.build("picche_c2"))
	)


func test_buttare_carte_costa_sempre_di_piu() -> void:
	run.earn(200)
	var primo := market.remove_price()
	assert_true(market.remove_card(run.collection[0], run))
	assert_gt(market.remove_price(), primo, "la seconda rimozione costa più della prima")


# --- acquisti ------------------------------------------------------------

func test_comprare_scala_l_oro_e_ingrossa_il_mazzo() -> void:
	run.earn(100)
	var oro := run.gold()
	var carte := run.deck_size()
	var prezzo := market.card_price(market.card_offers[0])

	var comprata := market.buy_card(0, run)
	assert_not_null(comprata)
	assert_eq(run.gold(), oro - prezzo)
	assert_eq(run.deck_size(), carte + 1)
	assert_eq(market.card_offers.size(), Cfg.get_int("shop.card_offers", 3) - 1, "l'offerta sparisce")


func test_senza_oro_non_si_compra_niente() -> void:
	run.wallet.set_amount(RunState.GOLD, 0.0)
	var carte := run.deck_size()
	assert_null(market.buy_card(0, run))
	assert_eq(run.deck_size(), carte)
	assert_eq(market.card_offers.size(), Cfg.get_int("shop.card_offers", 3), "la vetrina resta intatta")


func test_un_indice_inesistente_non_fa_danni() -> void:
	run.earn(100)
	var oro := run.gold()
	assert_null(market.buy_card(99, run))
	assert_eq(run.gold(), oro)


func test_buttare_una_carta_la_toglie_davvero() -> void:
	run.earn(100)
	var vittima := run.collection[3]
	var carte := run.deck_size()
	assert_true(market.remove_card(vittima, run))
	assert_eq(run.deck_size(), carte - 1)
	assert_eq(run.collection.find(vittima), -1)


# --- sigilli -------------------------------------------------------------

func test_un_sigillo_si_posa_su_una_carta_e_la_cambia() -> void:
	run.earn(100)
	market.seal_offers = [Content.entry("seals", "affilato")]
	var card := run.collection[0]
	var prima := card.value()

	assert_true(market.buy_seal(0, card, run))
	assert_gt(card.value(), prima, "affilato deve alzare il valore")
	assert_true(card.has_seal("affilato"))
	assert_true(market.seal_offers.is_empty(), "il sigillo comprato sparisce dalla vetrina")


func test_una_carta_con_due_sigilli_non_ne_prende_un_terzo() -> void:
	run.earn(100)
	var card := run.collection[0]
	card.add_seal(Content.entry("seals", "affilato"))
	card.add_seal(Content.entry("seals", "svelto"))

	market.seal_offers = [Content.entry("seals", "pesante")]
	var oro := run.gold()
	assert_false(market.buy_seal(0, card, run))
	assert_eq(run.gold(), oro, "un acquisto fallito non deve costare niente")


func test_senza_oro_il_sigillo_non_si_applica() -> void:
	run.wallet.set_amount(RunState.GOLD, 0.0)
	market.seal_offers = [Content.entry("seals", "eco")]
	var card := run.collection[0]
	assert_false(market.buy_seal(0, card, run))
	assert_eq(card.seals.size(), 0)


func test_ogni_sigillo_del_catalogo_fa_qualcosa() -> void:
	for seal in Content.list("seals"):
		var id := String(seal.get("id", ""))
		var agisce: bool = (
			seal.has("value_mult") or seal.has("cooldown_mult")
			or seal.has("cooldown_add") or not (seal.get("extra_effects", []) as Array).is_empty()
		)
		assert_true(agisce, "il sigillo %s non fa niente" % id)
		assert_gt(int(seal.get("cost", 0)), 0, "il sigillo %s è gratis" % id)
