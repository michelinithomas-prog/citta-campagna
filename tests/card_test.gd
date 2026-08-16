extends TestCase
## Le carte: la formula seme+valore, i sigilli, la pila che non rimescola.


# --- costruzione ---------------------------------------------------------

func test_la_carta_deriva_valore_e_attesa_dal_seme() -> void:
	var card := CardLibrary.build("picche_c7")
	assert_not_null(card, "picche_c7 deve esistere")
	assert_eq(card.value(), 7)
	# L'attesa la fanno in due: il seme (picche: 2.0 + 0.30 per punto) e il
	# valore, che può aggiungerne del suo (il Sette si prende 0.4s per il debuff).
	assert_almost(card.interval(), 2.0 + 7 * 0.30 + 0.4, 0.001)
	assert_eq(card.family, "poker")


func test_la_campagna_e_piu_lenta_e_piu_grossa_della_citta() -> void:
	var citta := CardLibrary.build("picche_c7")
	var campagna := CardLibrary.build("spade_r7")
	assert_gt(campagna.interval(), citta.interval(), "spade più lente delle picche")
	assert_eq(campagna.family, "briscola")


func test_seme_e_valore_di_famiglie_diverse_non_fanno_una_carta() -> void:
	# c13 è un valore da poker: non esiste un "re di spade" romagnolo con quell'id.
	assert_null(CardLibrary.build_from("spade", "c13"))


func test_tutte_le_carte_generabili_sono_valide() -> void:
	var ids := CardLibrary.all_ids()
	# Non è più un semplice prodotto seme × valore: le carte fuori seme — il
	# Jolly, L'antigh, il Germoglio — si tengono il proprio valore per sé.
	assert_gt(ids.size(), 0, "nessuna carta costruibile")
	var visti := {}
	for id in ids:
		assert_false(visti.has(id), "carta contata due volte: %s" % id)
		visti[id] = true
	for id in ids:
		var card := CardLibrary.build(id)
		assert_not_null(card, "carta non costruibile: %s" % id)
		assert_gt(card.interval(), 0.0, "%s ha attesa nulla" % id)
		assert_false(card.effects.is_empty() and card.tick_effects.is_empty()
				and card.enter_effects.is_empty(),
			"%s non fa niente: né entrando, né aspettando, né attivandosi" % id)


# --- sigilli -------------------------------------------------------------

func test_un_sigillo_accorcia_l_attesa() -> void:
	var card := CardLibrary.build("picche_c7")
	var prima := card.interval()
	assert_true(card.add_seal({"id": "svelto", "cooldown_mult": 0.7}))
	assert_almost(card.interval(), prima * 0.7, 0.001)


func test_un_sigillo_potenzia_il_valore() -> void:
	var card := CardLibrary.build("spade_r4")
	assert_true(card.add_seal({"id": "pesante", "value_mult": 1.5}))
	assert_eq(card.value(), 6, "4 × 1.5")


func test_oltre_due_sigilli_la_carta_non_ne_prende_altri() -> void:
	var card := CardLibrary.build("picche_c7")
	assert_true(card.add_seal({"id": "a", "cooldown_mult": 0.9}))
	assert_true(card.add_seal({"id": "b", "cooldown_mult": 0.9}))
	assert_false(card.add_seal({"id": "c", "cooldown_mult": 0.9}), "il terzo va rifiutato")
	assert_eq(card.seals.size(), Card.MAX_SEALS)


func test_la_copia_e_indipendente() -> void:
	var card := CardLibrary.build("picche_c7")
	var copy := card.clone()
	copy.add_seal({"id": "svelto", "cooldown_mult": 0.5})
	copy.stats.add_mod("value", StatBlock.FLAT, 5.0, "battle")
	assert_eq(card.value(), 7, "l'originale non deve muoversi")
	assert_eq(card.seals.size(), 0)


## `Card.clone()` copia campo per campo, e in battaglia si gioca solo con cloni:
## un campo nuovo che non viene aggiunto là dentro sparisce appena la carta
## scende in campo, senza un errore, senza un test rosso. Questo lo prende.
## Le uniche esclusioni sono dichiarate qui sotto, con il perché.
func test_il_clone_copia_ogni_campo() -> void:
	# `uses` sono contatori di una battaglia sola: il clone nasce a zero apposta.
	const VOLUTAMENTE_ESCLUSI := ["uses"]

	var card := CardLibrary.build("spade_r8")
	card.add_seal(Content.entry("seals", "affilato"))
	card.stats.add_mod("value", StatBlock.FLAT, 2.0, "run")
	card.cooldown_scale = 0.9
	card.cooldown = 3.25
	card.uses["recycle"] = 1

	var copy := card.clone()
	for property in card.get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var nome := String(property["name"])
		if nome.begins_with("_") or nome in VOLUTAMENTE_ESCLUSI:
			continue

		var originale: Variant = card.get(nome)
		var copiato: Variant = copy.get(nome)
		if originale is StatBlock:
			assert_almost((originale as StatBlock).get_stat("value"),
				(copiato as StatBlock).get_stat("value"),
				0.0001, "clone(): lo StatBlock di '%s' non è stato copiato" % nome)
			continue
		assert_eq(copiato, originale, "clone(): il campo '%s' non viene copiato" % nome)


# --- la pila -------------------------------------------------------------

func test_la_pila_finisce_e_resta_finita() -> void:
	var pile := CardPile.new(CardLibrary.deck_from_ids(["picche_c2", "picche_c3"]), RngStream.new(3))
	assert_eq(pile.remaining(), 2)

	var first := pile.draw()
	pile.discard(first)
	var second := pile.draw()
	pile.discard(second)

	assert_true(pile.is_empty())
	assert_null(pile.draw(), "gli scarti non rientrano mai: qui si perde la battaglia")
	assert_eq(pile.discarded(), 2)


func test_riciclare_rimanda_la_carta_in_fondo() -> void:
	var pile := CardPile.new(CardLibrary.deck_from_ids(["picche_c2", "picche_c3", "picche_c5"]), RngStream.new(3))
	var drawn := pile.draw()
	pile.recycle(drawn)
	assert_eq(pile.remaining(), 3)
	# in fondo significa: prima escono le altre due.
	pile.draw()
	pile.draw()
	assert_eq(pile.draw().id, drawn.id)


func test_stesso_seme_stessa_mescolata() -> void:
	var ids := ["picche_c2", "picche_c3", "picche_c5", "spade_r4", "coppe_r6"]
	var a := CardPile.new(CardLibrary.deck_from_ids(ids), RngStream.new(99))
	var b := CardPile.new(CardLibrary.deck_from_ids(ids), RngStream.new(99))
	for i in ids.size():
		assert_eq(a.draw().id, b.draw().id, "la mescolata deve essere riproducibile")


# --- generazione ---------------------------------------------------------

func test_la_ricetta_produce_un_mazzo_della_misura_giusta() -> void:
	var deck := CardLibrary.generate(RngStream.new(11), {
		"deck_size": 14, "weights": {"poker": 1.0, "briscola": 1.0}, "value_range": [2, 6]
	})
	assert_eq(deck.size(), 14)
	for card in deck:
		assert_gt(card.value(), 1, "%s fuori dall'intervallo richiesto" % card.id)
		assert_lt(card.value(), 7, "%s fuori dall'intervallo richiesto" % card.id)


func test_una_ricetta_di_sola_citta_non_pesca_campagna() -> void:
	var deck := CardLibrary.generate(RngStream.new(4), {
		"deck_size": 12, "weights": {"poker": 1.0, "briscola": 0.0}
	})
	assert_eq(deck.size(), 12)
	for card in deck:
		assert_eq(card.family, "poker", "%s non è una carta di poker" % card.id)


# --- integrità dei dati --------------------------------------------------

func test_il_mazzo_iniziale_esiste_davvero() -> void:
	var starting: Array = Cfg.get_value("deck.starting", [])
	assert_false(starting.is_empty(), "tuning.json: deck.starting è vuoto")
	for id in starting:
		assert_not_null(CardLibrary.build(String(id)), "carta iniziale inesistente: %s" % id)


func test_ogni_seme_ha_effetti_e_attesa() -> void:
	# Solo i semi che si possono davvero comprare: un mazzo ancora senza tema
	# vive nei dati con gli effetti vuoti apposta, ed è marcato fuori dal pool.
	var famiglie_del_pool: Array[String] = []
	for family in CardLibrary.pool_families():
		famiglie_del_pool.append(String(family.get("id", "")))

	for suit in Content.list("suits"):
		var id := String(suit.get("id", ""))
		assert_has(suit, "family", "%s: manca la famiglia" % id)
		assert_has(suit, "cooldown", "%s: manca l'attesa" % id)
		if not String(suit.get("family", "")) in famiglie_del_pool:
			continue
		assert_false((suit.get("effects", []) as Array).is_empty(), "%s: nessun effetto" % id)
