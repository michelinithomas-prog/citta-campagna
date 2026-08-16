extends TestCase
## La run: vite, oro, mazzo che cresce e si assottiglia, avanzamento dei round.

var run: RunState


func before_each() -> void:
	run = RunState.new(RngStream.new(5))
	# Il tutorial non conta né come vittoria né come sconfitta: questi test
	# parlano di quello che viene dopo.
	run.tutorial = false


func after_each() -> void:
	run = null


func test_la_run_parte_dal_mazzo_di_tuning() -> void:
	assert_eq(run.deck_size(), (Cfg.get_value("deck.starting", []) as Array).size())
	assert_eq(run.round_number, 1)
	assert_eq(run.lives, Cfg.get_int("player.lives", 2))
	assert_eq(run.gold(), Cfg.get_int("shop.starting_gold", 5))


func test_il_mazzo_di_battaglia_e_fatto_di_copie() -> void:
	var deck := run.battle_deck()
	assert_eq(deck.size(), run.deck_size())

	deck[0].stats.add_mod("value", StatBlock.FLAT, 99.0, "battle")
	assert_eq(run.collection[0].value(), deck[0].value() - 99,
		"quello che succede in battaglia non deve toccare il mazzo della run")


func test_vincere_un_round_frutta_il_bonus_e_manda_avanti() -> void:
	var prima := run.gold()
	assert_true(run.finish_round(true))
	assert_eq(run.round_number, 2)
	assert_eq(run.gold(), prima + Cfg.get_int("shop.win_bonus", 3) + Cfg.get_int("shop.gold_per_round", 6))
	assert_eq(run.lives, Cfg.get_int("player.lives", 2), "vincere non costa vite")


func test_perdere_costa_una_vita() -> void:
	var vite := run.lives
	run.finish_round(false)
	assert_eq(run.lives, vite - 1)


func test_a_zero_vite_la_run_e_finita() -> void:
	# Non si conta più una vita a sconfitta: più si va avanti più costa cadere,
	# quindi le vite possono anche saltare lo zero e finire sotto.
	var giri := 0
	while run.lives > 0 and giri < 40:
		run.finish_round(false)
		giri += 1
	assert_lt(run.lives, 1, "prima o poi le vite devono finire")
	assert_false(run.finish_round(false), "senza vite non si va avanti")


func test_perdere_tardi_costa_piu_che_perdere_presto() -> void:
	var presto := run.life_cost()
	while run.round_number < 5:
		run.finish_round(true)
	assert_gt(run.life_cost(), presto,
		"una sconfitta al quinto round deve pesare più di una al primo")


func test_l_ultimo_round_chiude_la_run() -> void:
	while not run.is_last_round():
		assert_true(run.finish_round(true))
	assert_false(run.finish_round(true), "dopo l'ultimo avversario la run finisce")


func test_ogni_round_ha_il_suo_avversario() -> void:
	for i in run.total_rounds():
		var recipe := run.opponent_for_round()
		assert_false(recipe.is_empty(), "round %d senza avversario" % run.round_number)
		assert_has(recipe, "deck_size")
		run.finish_round(true)


# --- mazzo ---------------------------------------------------------------

func test_aggiungere_una_carta() -> void:
	var prima := run.deck_size()
	assert_true(run.add_card(CardLibrary.build("picche_c9")))
	assert_eq(run.deck_size(), prima + 1)


func test_il_mazzo_non_ha_un_tetto() -> void:
	# Comprare non si ferma mai per regolamento: chi vuole un mazzo da cinquanta
	# carte può averlo, e se ne pentirà da solo — le carte buone si diluiscono e
	# la partita non gliele mette più in mano quando servono.
	var quante := run.deck_size()
	for i in 40:
		assert_true(run.add_card(CardLibrary.build("picche_c2")), "aggiunta %d rifiutata" % i)
	assert_eq(run.deck_size(), quante + 40)


func test_il_mazzo_non_scende_sotto_il_minimo() -> void:
	while run.can_remove():
		assert_true(run.remove_card(run.collection[0]))
	assert_eq(run.deck_size(), Cfg.get_int("deck.min_size", 10))
	assert_false(run.remove_card(run.collection[0]), "sotto il minimo il mazzo finirebbe subito")


# --- bonus passivi -------------------------------------------------------

func test_un_passivo_di_famiglia_tocca_solo_la_sua_famiglia() -> void:
	run.passives.append({"family": "poker", "value_add": 3})
	var deck := run.battle_deck()

	for i in run.collection.size():
		var atteso := run.collection[i].value()
		if run.collection[i].family == "poker":
			atteso += 3
		assert_eq(deck[i].value(), atteso, "%s non ha il valore giusto" % deck[i].id)


func test_un_passivo_di_velocita_accorcia_l_attesa() -> void:
	run.passives.append({"suit": "spade", "cooldown_scale": 0.5})
	var deck := run.battle_deck()
	for i in run.collection.size():
		if run.collection[i].suit_id == "spade":
			assert_almost(deck[i].interval(), run.collection[i].interval() * 0.5, 0.001)


# --- chi ha vinto la run -------------------------------------------------

func test_battere_l_ultimo_avversario_e_una_vittoria() -> void:
	while not run.is_last_round():
		run.finish_round(true)
	assert_false(run.victory, "prima dell'ultima battaglia non si è vinto niente")
	run.finish_round(true)
	assert_true(run.victory)


func test_si_vince_anche_arrivando_in_fondo_a_zero_vite() -> void:
	# Le vite si possono perdere anche fuori dalle battaglie (l'evento del
	# temporale). Arrivare in fondo scarichi è un finale magro, non una
	# sconfitta: prima questo caso mostrava la schermata "Sconfitta" a chi
	# aveva appena vinto l'ultimo round.
	while not run.is_last_round():
		run.finish_round(true)
	run.lives = 0
	assert_false(run.finish_round(true), "la run finisce")
	assert_true(run.victory, "l'ultimo round è stato vinto: è una vittoria")


func test_perdere_l_ultimo_round_non_e_una_vittoria() -> void:
	while not run.is_last_round():
		run.finish_round(true)
	run.finish_round(false)
	assert_false(run.victory)


func test_finire_le_vite_a_meta_run_non_e_una_vittoria() -> void:
	for i in run.lives:
		run.finish_round(false)
	assert_false(run.victory)


func test_le_statistiche_finali_hanno_la_chiave_del_record() -> void:
	# game_over.gd cerca stats[menu.best_stat]: se non combacia, il record non
	# si salva mai e nessuno se ne accorge.
	assert_has(run.stats(), String(Cfg.get_value("menu.best_stat", "")))


# --- come si vince -------------------------------------------------------

func test_si_vince_con_dieci_vittorie_non_con_otto_round() -> void:
	var servono := run.wins_needed()
	for i in servono - 1:
		assert_true(run.finish_round(true), "alla %da vittoria si va ancora avanti" % (i + 1))
		assert_false(run.victory)

	assert_false(run.finish_round(true), "l'ultima vittoria chiude la partita")
	assert_true(run.victory)
	assert_eq(run.wins, servono)


func test_perdere_non_fa_avanzare_l_avversario() -> void:
	# Chi perde se lo ritrova davanti: l'avversario dipende dalle vittorie, non
	# dalle partite giocate.
	var primo := run.opponent_for_round()
	run.finish_round(false)
	assert_eq(run.opponent_for_round(), primo, "perdere non ti fa saltare avanti")

	run.finish_round(true)
	assert_ne(run.opponent_for_round(), primo, "vincere sì")


func test_si_puo_perdere_pur_avendo_vinto_qualcosa() -> void:
	run.finish_round(true)
	run.finish_round(true)
	while run.lives > 0:
		run.finish_round(false)
	assert_false(run.victory, "due vittorie su dieci non sono una vittoria")
	assert_gt(run.wins, 0)
