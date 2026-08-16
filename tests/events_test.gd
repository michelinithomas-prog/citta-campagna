extends TestCase
## Gli incontri: pescata, scelte, effetti sulla run, riproducibilità.

var run: RunState
var book: EventBook


func before_each() -> void:
	run = RunState.new(RngStream.new(3))
	book = EventBook.new(RngStream.new(3))
	# Il tutorial non conta né come vittoria né come sconfitta: questi test
	# parlano di quello che viene dopo.
	run.tutorial = false


func after_each() -> void:
	if book != null:
		book.clear_handlers()
		book = null
	run = null


func _event(id: String) -> Dictionary:
	return Content.entry("events", id)


# --- pescata -------------------------------------------------------------

func test_al_primo_round_non_capita_niente() -> void:
	assert_false(book.should_trigger(1), "il primo round deve essere pulito")


func test_lo_stesso_evento_non_capita_due_volte() -> void:
	var visti := {}
	for i in Content.list("events").size():
		var event := book.draw(9)
		if event.is_empty():
			break
		var id := String(event.get("id", ""))
		assert_false(visti.has(id), "l'evento %s è uscito due volte" % id)
		visti[id] = true
	assert_true(book.draw(9).is_empty(), "finiti gli eventi non se ne pescano altri")


func test_gli_eventi_rispettano_il_round_minimo() -> void:
	for i in 20:
		var event := book.draw(2)
		if event.is_empty():
			break
		assert_lt(int(event.get("min_round", 1)), 3, "%s non doveva uscire al round 2" % event.get("id"))


# --- effetti -------------------------------------------------------------

func test_una_scelta_di_oro_paga() -> void:
	var oro := run.gold()
	book.choose(_event("fiera"), 0, run)
	assert_eq(run.gold(), oro + 12)


func test_una_scelta_puo_togliere_una_carta() -> void:
	# Alla fiera si vende: dodici oro in mano e una carta in meno nel carro.
	run.earn(50)
	var carte := run.deck_size()
	var oro := run.gold()
	book.choose(_event("fiera"), 0, run)
	assert_eq(run.deck_size(), carte - 1)
	assert_eq(run.gold(), oro + 12)


func test_un_passivo_resta_per_tutta_la_run() -> void:
	# I Racconti dell'oste velocizzano le carte di briscola, e continuano a farlo
	# a ogni battaglia: il passivo viene applicato alle copie che scendono in campo.
	book.choose(_event("osteria"), 1, run)
	assert_eq(run.passives.size(), 1)
	assert_true(run.has_relic("racconti"))

	var deck := run.battle_deck()
	for i in run.collection.size():
		var atteso := run.collection[i].interval()
		if run.collection[i].family == "briscola":
			atteso *= 0.9
		assert_almost(deck[i].interval(), atteso, 0.001,
			"%s non ha l'attesa giusta" % deck[i].id)


func test_nessun_evento_regala_lo_stesso_bonus_di_una_reliquia() -> void:
	# Due fonti per lo stesso identico bonus rendono una delle due inutile: chi
	# ha già preso l'Almanacco non ha motivo di fermarsi all'osteria. Le regole
	# possono somigliarsi, non coincidere.
	var regole_reliquie: Array[String] = []
	for relic in Content.list("relics"):
		if relic.has("rule"):
			regole_reliquie.append(JSON.stringify(relic["rule"]))

	for entry in Content.list("events"):
		for choice in entry.get("choices", []):
			for effect in choice.get("effects", []):
				if effect is Dictionary and (effect as Dictionary).has("rule"):
					var regola := JSON.stringify((effect as Dictionary)["rule"])
					assert_false(regola in regole_reliquie,
						'l\'evento "%s" regala la stessa regola di una reliquia: %s'
							% [entry.get("id", "?"), regola])


func test_un_sigillo_regalato_finisce_su_una_carta() -> void:
	book.choose(_event("fabbro"), 0, run)
	var sigillate := 0
	for card in run.collection:
		if card.has_seal("affilato"):
			sigillate += 1
	assert_eq(sigillate, 1, "il fabbro deve aver affilato esattamente una carta")


func test_una_scelta_a_rischio_e_riproducibile() -> void:
	# Il rischio passa da EffectResolver e quindi dallo stream: a parità di seed
	# l'esito è sempre lo stesso, altrimenti F8 (rigioca lo stesso seed) mente.
	var esiti: Array = []
	for run_index in 2:
		var stato := RunState.new(RngStream.new(11))
		var libro := EventBook.new(RngStream.new(11))
		libro.choose(_event("temporale"), 1, stato)
		esiti.append([stato.gold(), stato.lives])
		libro.clear_handlers()
	assert_eq(esiti[0], esiti[1])


func test_una_scelta_inesistente_non_fa_danni() -> void:
	var oro := run.gold()
	assert_true(book.choose(_event("fiera"), 99, run).is_empty())
	assert_eq(run.gold(), oro)


func test_ogni_scelta_di_ogni_evento_si_applica_senza_esplodere() -> void:
	# Passata su tutto il contenuto: prende gli id scritti male e gli effetti
	# senza handler, che altrimenti si scoprirebbero solo in partita.
	for entry in Content.list("events"):
		for i in (entry.get("choices", []) as Array).size():
			var stato := RunState.new(RngStream.new(7))
			var libro := EventBook.new(RngStream.new(7))
			libro.choose(entry, i, stato)
			assert_gt(stato.deck_size(), 0, "%s scelta %d ha svuotato il mazzo" % [entry.get("id"), i])
			libro.clear_handlers()


# --- integrità dei dati --------------------------------------------------

func test_ogni_evento_e_scritto_bene() -> void:
	for entry in Content.list("events"):
		var id := String(entry.get("id", ""))
		assert_true(entry.has("text"), "%s: manca il testo" % id)
		var choices: Array = entry.get("choices", [])
		assert_gt(choices.size(), 0, "%s: un incontro senza scelte non è un incontro" % id)
		for choice in choices:
			assert_has(choice, "label", "%s: una scelta senza etichetta" % id)

		# Un incontro con una scelta sola è legittimo — c'è chi ti fa un regalo e
		# basta — ma allora il regalo deve esserci: altrimenti è una finestra da
		# chiudere, non un incontro.
		if choices.size() == 1:
			assert_false((choices[0].get("effects", []) as Array).is_empty(),
				"%s: una scelta sola e per giunta senza effetti è solo un bottone da premere" % id)


func test_ogni_sigillo_citato_dagli_eventi_esiste() -> void:
	for entry in Content.list("events"):
		for choice in entry.get("choices", []):
			for effect in choice.get("effects", []):
				_check_seal_ids(effect, String(entry.get("id", "")))


## Gli effetti si annidano dentro chance e random: la verifica deve scendere.
func _check_seal_ids(effect: Variant, event_id: String) -> void:
	if not effect is Dictionary:
		return
	var data: Dictionary = effect
	if data.has("seal"):
		assert_true(Content.has("seals", String(data["seal"])),
			"%s cita un sigillo inesistente: %s" % [event_id, data["seal"]])
	for key in ["effect", "else"]:
		if data.has(key):
			_check_seal_ids(data[key], event_id)
	for nested in data.get("effects", []):
		_check_seal_ids(nested, event_id)


# --- i verbi nuovi -------------------------------------------------------

func test_un_incontro_puo_regalare_una_reliquia_precisa() -> void:
	book.choose(_event("osteria"), 1, run)
	assert_true(run.has_relic("racconti"), "l'oste doveva lasciarti i suoi Racconti")


func test_la_reliquia_a_caso_non_pesca_fra_quelle_degli_incontri() -> void:
	# "Una reliquia a caso" deve dare qualcosa che si sarebbe potuto comprare,
	# non una delle tre che esistono solo per gli incontri: quelle sono premi
	# scritti a mano, e regalarle a sorte le svuoterebbe.
	for giro in 12:
		var suo := RunState.new(RngStream.new(giro + 1))
		var libro := EventBook.new(RngStream.new(giro + 1))
		libro.choose(_event("colletta"), 0, suo)
		for relic in suo.relics:
			assert_true(bool(relic.get("in_shop", true)),
				"la colletta ha regalato %s, che si prende solo agli incontri" % relic.get("name"))
		libro.clear_handlers()


func test_una_reliquia_a_tempo_scade_e_si_porta_via_la_sua_regola() -> void:
	book.choose(_event("sagra"), 1, run)
	assert_true(run.has_relic("notte"))
	var passivi := run.passives.size()
	assert_gt(passivi, 0, "la Notte deve aver messo la sua regola")

	var durata := int(Content.entry("relics", "notte").get("rounds", 3))
	for i in durata:
		run.finish_round(true)

	assert_false(run.has_relic("notte"), "dopo tre incontri la notte è passata")
	assert_eq(run.passives.size(), passivi - 1, "e con lei la sua regola")


func test_una_scelta_puo_chiudere_la_partita() -> void:
	assert_false(run.abandoned)
	book.choose(_event("scelta"), 0, run)
	assert_true(run.abandoned, "c'è una scelta che finisce la run, ed è quella giusta")
	assert_false(run.finish_round(true), "e da lì non si va più avanti")


func test_una_scelta_puo_lasciarti_lo_strascico_per_la_prossima_battaglia() -> void:
	book.choose(_event("shock"), 1, run)
	assert_gt(float(run.next_battle.get("paralyzed", 0.0)), 0.0,
		"chi rovista nel bidone se la porta dietro")
	assert_gt(run.count_family("gaiofanamon"), 0, "e si porta a casa Sorc")


func test_lo_scambio_capita_solo_a_chi_ha_un_gaiofanamon() -> void:
	var senza := book.available(9, run)
	assert_false(_contiene(senza, "scambio"), "senza creature non c'è niente da scambiare")

	run.add_card(CardLibrary.build("acqua_g1"))
	assert_true(_contiene(book.available(9, run), "scambio"))


func test_il_professore_non_regala_il_secondo_starter() -> void:
	assert_true(_contiene(book.available(9, run), "professore"))
	run.add_card(CardLibrary.build("fuoco_g1"))
	assert_false(_contiene(book.available(9, run), "professore"),
		"chi ne ha già uno non se lo sente offrire di nuovo")


func test_lo_scambio_da_una_creatura_di_un_altro_seme_ma_dello_stesso_stadio() -> void:
	run.add_card(CardLibrary.build("acqua_g1"))
	var quante := run.deck_size()

	book.choose(_event("scambio"), 0, run)
	assert_eq(run.deck_size(), quante, "una esce, una entra")

	var trovata: Card = null
	for card in run.collection:
		if card.family == "gaiofanamon":
			trovata = card
	assert_not_null(trovata)
	assert_ne(trovata.suit_id, "acqua", "il ragazzino te ne dà una diversa")
	assert_eq(trovata.rank_id, "g1", "ma dello stesso stadio: non è un imbroglio")


func _contiene(pool: Array, id: String) -> bool:
	for entry in pool:
		if String(entry.get("id", "")) == id:
			return true
	return false
