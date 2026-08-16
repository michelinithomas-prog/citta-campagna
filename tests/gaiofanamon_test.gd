extends TestCase
## I gaiofanamon: le creature che crescono.
##
## Sono l'unico mazzo che cambia da solo mentre la partita va avanti, e la cosa
## che questi test difendono è **che la crescita esca dalla battaglia**. Se
## restasse dentro, ogni round ricomincerebbe dai cuccioli e l'evoluzione
## sarebbe un'animazione: la carta si attiva, diventa grande, muore, e al round
## dopo è di nuovo piccola come prima. È già successo, e nessun test se ne
## accorgeva perché la battaglia in sé funzionava benissimo.


func _run_vuota() -> RunState:
	var run := RunState.new(RngStream.new(11))
	run.tutorial = false
	run.collection.clear()
	return run


## Una battaglia col mazzo dato, giocata fino in fondo. Torna il Duel, che si
## porta dietro il conto delle evoluzioni.
func _battaglia(run: RunState, seed: int, hp := 200) -> Duel:
	var mio := Side.new("io", run.battle_deck(), RngStream.new(seed), {"hp": hp, "is_player": true})
	var suo := Side.new("lui", CardLibrary.generate(RngStream.new(seed + 99),
		{"deck_size": 30, "value_range": [3, 9]}), RngStream.new(seed + 7), {"hp": hp})
	var duel := Duel.new(mio, suo, RngStream.new(seed + 3))
	duel.simulate_to_end()
	return duel


# --- le linee -------------------------------------------------------------

func test_le_linee_salgono_di_livello_e_poi_si_fermano() -> void:
	for seme in ["acqua", "fuoco", "erba"]:
		var uno := CardLibrary.build("%s_g1" % seme)
		assert_eq(uno.evolves_to, "g2", "%s: il cucciolo deve crescere" % seme)
		var due := CardLibrary.build("%s_g2" % seme)
		assert_eq(due.evolves_to, "g3", "%s: l'adulto deve crescere" % seme)
		var tre := CardLibrary.build("%s_g3" % seme)
		assert_eq(tre.evolves_to, "", "%s: il veterano è l'ultimo" % seme)


func test_l_elettro_finisce_al_secondo_livello() -> void:
	# Rataz non ha un livello dopo. Non è un buco nei dati: è la linea che finisce
	# lì, e `elettro_g3` non deve nemmeno essere costruibile — una carta senza
	# nome e senza disegno che nessuno può raggiungere è solo un modo per far
	# passare un errore inosservato.
	assert_eq(CardLibrary.build("elettro_g2").evolves_to, "")
	assert_false("elettro_g3" in CardLibrary.all_ids(),
		"elettro_g3 non deve esistere: la linea elettro ha due livelli")


func test_solo_i_cuccioli_si_comprano() -> void:
	var pool := CardLibrary.pool_ids()
	for seme in ["acqua", "fuoco", "erba", "elettro"]:
		assert_true("%s_g1" % seme in pool, "%s_g1 deve essere in bottega" % seme)
		assert_false("%s_g2" % seme in pool, "%s_g2 non si compra: si cresce" % seme)


func test_ogni_creatura_ha_il_suo_disegno() -> void:
	# Il disegno dei gaiofanamon si trova per nome, e i nomi su disco non sono
	# quelli scritti nei dati: `E' Canon` sta in `Canon.png`. Bastava che la mappa
	# non parlasse la stessa lingua dei file perché tredici carte su quindici
	# restassero bianche senza che niente si lamentasse.
	CarteArt.dimentica()
	for id in CardLibrary.all_ids():
		var card := CardLibrary.build(id)
		if card == null or card.family != "gaiofanamon":
			continue
		assert_not_null(CarteArt.per_carta(card), "%s (%s) non trova il suo disegno" % [id, card.display_name])


# --- l'evoluzione dentro la battaglia --------------------------------------

func test_evolvere_si_porta_dietro_sigilli_ritmo_e_passivi() -> void:
	# È la stessa creatura che è cresciuta, non una carta nuova che le somiglia:
	# quello che il giocatore ha pagato per metterle addosso deve seguirla.
	var duel := Duel.new(
		Side.new("a", [CardLibrary.build("acqua_g1")], RngStream.new(1), {"hp": 10}),
		Side.new("b", [CardLibrary.build("picche_c1")], RngStream.new(2), {"hp": 10}),
		RngStream.new(3))

	var cucciolo := CardLibrary.build("acqua_g1")
	cucciolo.add_seal(Content.entry("seals", "affilato"))
	cucciolo.cooldown_scale = 0.8
	cucciolo.stats.add_mod("value", StatBlock.FLAT, 2.0, "run")

	var cresciuto := duel._evolvi(cucciolo)
	assert_not_null(cresciuto)
	assert_eq(cresciuto.id, "acqua_g2")
	assert_eq(cresciuto.seals.size(), 1, "il sigillo resta sulla creatura")
	assert_almost(cresciuto.cooldown_scale, 0.8)
	assert_eq(cresciuto.stats.mods_from("run").size(), 1, "i passivi della run seguono")
	duel.resolver.clear_handlers()


func test_una_creatura_nata_in_battaglia_non_ha_un_posto_nel_mazzo() -> void:
	# Un Germoglio e la creatura svegliata dall'Antigh vivono una battaglia sola:
	# senza `origin` finirebbero a sovrascrivere una carta a caso della collezione.
	assert_eq(CardLibrary.build("germoglio_s1").origin, -1)
	assert_eq(CardLibrary.build("acqua_g1").origin, -1,
		"una carta appena costruita non viene da nessun mazzo")


func test_il_mazzo_da_battaglia_marca_il_posto_di_ogni_carta() -> void:
	var run := _run_vuota()
	for id in ["picche_c5", "acqua_g1", "acqua_g1"]:
		run.collection.append(CardLibrary.build(id))

	var mazzo := run.battle_deck()
	for i in mazzo.size():
		assert_eq(mazzo[i].origin, i, "la copia %d ha perso il biglietto di ritorno" % i)


# --- l'evoluzione fuori dalla battaglia ------------------------------------

func test_la_crescita_arriva_nel_mazzo() -> void:
	var run := _run_vuota()
	for id in ["acqua_g1", "fuoco_g1", "erba_g1", "elettro_g1", "acqua_g1", "fuoco_g1"]:
		run.collection.append(CardLibrary.build(id))

	var duel := _battaglia(run, 4)
	assert_gt(duel.evoluzioni.size(), 0, "sei creature in campo e nessuna è cresciuta")

	var quante := run.evolvi(duel.evoluzioni)
	assert_eq(quante, duel.evoluzioni.size())
	for posto in duel.evoluzioni:
		assert_eq(run.collection[int(posto)].id, String(duel.evoluzioni[posto]),
			"il posto %s non ha incassato la crescita" % posto)
	duel.resolver.clear_handlers()


func test_cresce_solo_la_copia_che_e_scesa_in_campo() -> void:
	# Tre Sgorga identiche nel mazzo: il nome non basta a dire quale è cresciuta,
	# e nemmeno l'oggetto — ogni battaglia gioca con cloni.
	var run := _run_vuota()
	for id in ["acqua_g1", "acqua_g1", "acqua_g1"]:
		run.collection.append(CardLibrary.build(id))

	assert_eq(run.evolvi({1: "acqua_g2"}), 1)
	assert_eq(run.collection[0].id, "acqua_g1")
	assert_eq(run.collection[1].id, "acqua_g2")
	assert_eq(run.collection[2].id, "acqua_g1", "le altre due non si muovono")


func test_la_crescita_si_tiene_anche_se_la_battaglia_va_male() -> void:
	# Perdere costa già delle vite. I gaiofanamon sono l'unico archetipo che ha
	# bisogno di tempo per pagare: togliergli la crescita proprio nei round
	# difficili vorrebbe dire punirlo due volte.
	var run := _run_vuota()
	for i in 6:
		run.collection.append(CardLibrary.build("acqua_g1"))

	var duel := _battaglia(run, 8, 40)
	run.evolvi(duel.evoluzioni)

	var cresciute := 0
	for card in run.collection:
		if card.rank_id != "g1":
			cresciute += 1
	assert_gt(cresciute, 0, "nessuna creatura è cresciuta, e il test non prova niente")
	duel.resolver.clear_handlers()


func test_il_sigillo_sopravvive_alla_crescita_anche_nel_mazzo() -> void:
	var run := _run_vuota()
	var cucciolo := CardLibrary.build("acqua_g1")
	cucciolo.add_seal(Content.entry("seals", "affilato"))
	run.collection.append(cucciolo)

	run.evolvi({0: "acqua_g3"})
	assert_eq(run.collection[0].id, "acqua_g3")
	assert_eq(run.collection[0].seals.size(), 1, "il sigillo era della carta, non del livello")


func test_il_livello_raggiunto_si_salva() -> void:
	# Nel salvataggio ci vanno solo gli id: se l'evoluzione non arrivasse fin qui,
	# chi chiude e riapre ritroverebbe i cuccioli.
	var run := _run_vuota()
	run.collection.append(CardLibrary.build("fuoco_g1"))
	run.evolvi({0: "fuoco_g3"})

	var ripresa := RunState.from_dict(run.to_dict(), RngStream.new(2))
	assert_eq(ripresa.collection[0].id, "fuoco_g3")
	assert_eq(ripresa.collection[0].display_name, "E' dragh")


# --- L'antigh --------------------------------------------------------------

func test_l_antigh_sveglia_una_creatura_e_non_sempre_la_stessa() -> void:
	var viste := {}
	for seed in 30:
		# Un mazzo che regge: con poche carte la battaglia finisce per deck-out
		# prima che l'Antigh faccia in tempo a svegliarsi.
		var mazzo: Array[Card] = []
		for i in 12:
			mazzo.append(CardLibrary.build("antigh_a0" if i % 3 == 0 else "picche_c1"))
		var mio := Side.new("io", mazzo, RngStream.new(seed), {"hp": 300})
		var suo := Side.new("lui", CardLibrary.generate(RngStream.new(seed + 50),
			{"deck_size": 24, "value_range": [1, 5]}), RngStream.new(seed + 1), {"hp": 300})
		var duel := Duel.new(mio, suo, RngStream.new(seed + 2))
		duel.simulate_to_end()
		# Si cerca il seme, non il livello: la creatura svegliata entra in cima al
		# mazzo, scende in campo al primo rimpiazzo e da lì cresce — negli scarti
		# la si ritrova già adulta.
		for lista in [mio.pile.draw_pile, mio.pile.discard_pile]:
			for card in lista:
				if card.suit_id in ["acqua", "fuoco", "erba", "elettro"]:
					viste[card.suit_id] = true
		duel.resolver.clear_handlers()

	assert_gt(viste.size(), 0, "L'antigh non ha svegliato niente")

	assert_gt(viste.size(), 1,
		"L'antigh sveglia sempre la stessa creatura: era cablata, deve pescare fra le quattro")
	for seme in viste:
		assert_true(seme in ["acqua", "fuoco", "erba", "elettro"], "ha svegliato %s" % seme)


# --- il metro ---------------------------------------------------------------

func test_la_scala_dei_livelli_sale_e_non_sfonda() -> void:
	# I livelli 2 e 3 non si comprano, quindi `budget_test` non li guarda: sono
	# fuori da `pool_ids()`. Ma il giocatore ce li ha in mano, e sono il premio
	# di tutto l'archetipo — se scappano, scappa il gioco.
	for seme in ["acqua", "fuoco", "erba"]:
		var scala: Array[float] = []
		for livello in ["g1", "g2", "g3"]:
			scala.append(CardBudget.punti_al_secondo(CardLibrary.build("%s_%s" % [seme, livello])))
		assert_gt(scala[1], scala[0], "%s: l'adulto deve valere più del cucciolo" % seme)
		assert_gt(scala[2], scala[1], "%s: il veterano deve valere più dell'adulto" % seme)
		assert_lt(scala[2], 3.4, "%s: il veterano sfonda il tetto delle carte" % seme)


func test_i_quattro_semi_si_equivalgono_a_ogni_livello() -> void:
	# `budget_test` confronta i semi a parità di valore, ma solo sulle carte
	# comprabili: i livelli 2 e 3 sono `in_pool: false` e gli scivolano sotto.
	# Sono proprio quelli che il giocatore si ritrova in mano dal round dopo.
	for livello in ["g2", "g3"]:
		var minimo := INF
		var massimo := 0.0
		var peggiore := ""
		var migliore := ""
		for seme in ["acqua", "fuoco", "erba", "elettro"]:
			var card := CardLibrary.build("%s_%s" % [seme, livello])
			if card == null:
				continue  # l'elettro non ha il terzo livello
			var resa := CardBudget.punti_al_secondo(card)
			if resa < minimo:
				minimo = resa
				peggiore = seme
			if resa > massimo:
				massimo = resa
				migliore = seme
		assert_lt(massimo / minimo, 1.7,
			"livello %s: %s rende %.2f e %s solo %.2f — uno dei due non vale la pena di crescere"
			% [livello, migliore, massimo, peggiore, minimo])


func test_lo_scambio_non_inventa_carte_che_non_esistono() -> void:
	# "Lo scambio" prende una creatura e le cambia seme tenendo il livello. Ma non
	# tutti i semi accettano tutti i livelli: L'antigh ha un valore suo, l'elettro
	# non ha il veterano. Col solo filtro sulla famiglia si costruiva `fuoco_a0`,
	# che non è una carta — e l'incontro non faceva niente senza dirlo.
	for id in ["antigh_a0", "acqua_g3", "elettro_g2", "germoglio_s1"]:
		var run := _run_vuota()
		run.collection.append(CardLibrary.build(id))
		for i in 12:
			run.collection.append(CardLibrary.build("picche_c5"))
		var prima := CardLibrary.build(id)

		var libro := EventBook.new(RngStream.new(7))
		libro.choose(Content.entry("events", "scambio"), 0, run)
		libro.resolver.clear_handlers()

		# `remove_card` + `add_card`: la creatura scambiata finisce in fondo, non
		# resta al suo posto. Si cerca per famiglia.
		var creature: Array[Card] = []
		for card in run.collection:
			if card.family == "gaiofanamon":
				creature.append(card)

		assert_eq(creature.size(), 1, "%s: dopo lo scambio la creatura è una sola" % id)
		var dopo := creature[0]
		assert_not_null(CardLibrary.build(dopo.id), "%s è diventata %s, che non esiste" % [id, dopo.id])
		assert_eq(dopo.rank_id, prima.rank_id, "%s: lo scambio deve tenere il livello" % id)
