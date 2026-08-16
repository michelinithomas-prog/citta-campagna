extends TestCase
## La scheda che si apre sulle carte: quella che il giocatore legge davvero.
##
## La regola che questi test difendono è una sola: **un numero, un posto**. Se
## una carta colpisce da due parti la scheda deve dire quanto fa in tutto, non
## far sommare a mente; e se fa qualcosa che ha una regola dietro — veleno,
## catena, paralisi — quella regola deve essere raggiungibile da lì.

var scheda: CardDetail


func before_each() -> void:
	scheda = CardDetail.new()


func after_each() -> void:
	if scheda != null:
		scheda.free()
		scheda = null


func test_i_danni_di_una_carta_si_sommano_in_un_numero_solo() -> void:
	# Le Picche colpiscono col seme e col valore: due righe nei dati, un numero
	# solo negli occhi di chi gioca.
	var card := CardLibrary.build("picche_c10")
	var line := card.stat_line()

	var istanze := [0]
	card.walk_effects(func(effect: Dictionary, _peso: float) -> void:
		if String(effect.get("type", "")) == "damage":
			istanze[0] += 1
	)
	assert_gt(istanze[0], 1, "serve una carta che colpisca da più parti, o il test non prova niente")
	assert_gt(float(line["damage"]), 0.0, "e il totale deve essere uno solo")


func test_la_scheda_non_ripete_i_numeri_che_ha_gia_in_griglia() -> void:
	# Le righe "speciali" sono solo per i verbi che un numero non ce l'hanno.
	# Danni, scudo, cura, veleno, sangue e oro stanno nella griglia, e basta.
	var card := CardLibrary.build("spade_r10")
	for riga in scheda._righe_speciali(card, card.stat_line()):
		for parola in ["danni", "danno", "scudo", "cura"]:
			assert_false(String(riga).to_lower().contains(parola),
				'la riga "%s" ripete un numero che sta già nella griglia' % riga)


func test_ogni_carta_del_catalogo_produce_una_scheda() -> void:
	# La passata che prende gli id storti e i verbi senza descrizione: una carta
	# che non sa raccontarsi si scopre solo passandoci sopra il mouse.
	for card_id in CardLibrary.all_ids():
		var card := CardLibrary.build(card_id)
		if card == null:
			continue
		var line := card.stat_line()
		for riga in scheda._righe_speciali(card, line):
			assert_false(String(riga).is_empty(), "%s: una riga vuota" % card_id)
		for voce in scheda._glossario(card, line):
			assert_eq((voce as Array).size(), 2, "%s: una voce di glossario malformata" % card_id)
			assert_false(String(voce[1]).is_empty(), "%s: %s non è spiegato" % [card_id, voce[0]])


func test_chi_avvelena_spiega_cos_e_il_veleno() -> void:
	var card := CardLibrary.build("fiori_c5")
	var titoli := _titoli(card)
	assert_true("Veleno" in titoli, "una carta che avvelena deve saper dire cos'è il veleno")


func test_chi_fa_sanguinare_spiega_il_sanguinamento() -> void:
	var card := CardLibrary.build("spade_r10")
	var titoli := _titoli(card)
	assert_true("Sanguinamento" in titoli)
	assert_true("Colpo che buca" in titoli, "le Spade passano lo scudo, e va detto")


func test_una_carta_che_non_fa_niente_di_strano_non_ha_glossario() -> void:
	# Un Asso di Picche fa danni e basta: aprire un paragrafo su come funziona il
	# danno sarebbe rumore.
	var card := CardLibrary.build("picche_c1")
	assert_eq(_titoli(card).size(), 0)


func test_il_glossario_dice_i_numeri_veri_del_gioco() -> void:
	# Le spiegazioni citano il passo del veleno e il moltiplicatore della catena:
	# se qualcuno gira quelle manopole in tuning.json, la scheda non deve
	# continuare a raccontare come stavano le cose ieri.
	var card := CardLibrary.build("fiori_c5")
	var passo := int(Cfg.get_float("battle.poison_every", 3.0))
	for voce in scheda._glossario(card, card.stat_line()):
		if String(voce[0]) == "Veleno":
			assert_true(String(voce[1]).contains("%d second" % passo),
				"la spiegazione del veleno non cita il passo vero (%d s)" % passo)


func _titoli(card: Card) -> Array[String]:
	var out: Array[String] = []
	for voce in scheda._glossario(card, card.stat_line()):
		out.append(String(voce[0]))
	return out


func test_il_titolo_prende_il_colore_della_carta() -> void:
	# Il colore non è decorazione: è quello con cui si fa catena. Chi cerca "una
	# carta rossa" deve poterla riconoscere senza aprire niente.
	assert_eq(CardDetail.colore_del_titolo(CardLibrary.build("cuori_c12")), Hud.DANNO,
		"le Cuori sono rosse")
	assert_eq(CardDetail.colore_del_titolo(CardLibrary.build("quadri_c9")), Hud.DANNO,
		"i Quadri sono disegnati d'oro ma sono rossi, ed è il rosso che conta")
	assert_eq(CardDetail.colore_del_titolo(CardLibrary.build("blu_o3")), Hud.SCUDO)
	assert_eq(CardDetail.colore_del_titolo(CardLibrary.build("acqua_g1")), Hud.SCUDO,
		"un gaiofanamon d'acqua è blu quanto un Blu di One")


func test_chi_non_ha_colore_ha_un_titolo_neutro() -> void:
	# La briscola un colore non ce l'ha. Dargliene uno a caso vorrebbe dire dire
	# che fa catena con qualcosa: non è vero.
	assert_eq(CardDetail.colore_del_titolo(CardLibrary.build("denari_r10")), Hud.CREMA)
	assert_eq(CardDetail.colore_del_titolo(CardLibrary.build("jolly_j0")), Hud.CREMA)


func test_i_semi_neri_non_si_scrivono_di_nero() -> void:
	# Su un tavolo scuro un titolo nero non si legge, e l'informazione da passare
	# non è "è di questa tinta" ma "non è rosso".
	var nero := CardDetail.colore_del_titolo(CardLibrary.build("picche_c11"))
	assert_eq(nero, Hud.NERO_CARTA)
	assert_ne(nero, CardDetail.colore_del_titolo(CardLibrary.build("denari_r10")),
		"nero e neutro devono restare distinguibili")
	assert_true(nero.get_luminance() > 0.25, "un titolo così scuro non si legge")


func test_le_etichette_si_leggono_nella_scheda() -> void:
	# I tag decidono su chi cadono le reliquie e i bonus degli eventi: se non si
	# vedono, "le figure costano meno" è una promessa che il giocatore non può
	# verificare prima di comprare.
	var etichette := scheda._etichette(CardLibrary.build("picche_c11"))
	assert_true("figura" in etichette)
	assert_true("umano" in etichette)
	assert_true("dispari" in etichette)


func test_le_etichette_di_servizio_restano_fuori() -> void:
	# `mazzo:poker`, `seme:picche`, `valore:11` servono ai filtri, ma nella scheda
	# ripeterebbero tre cose scritte due righe più su.
	for etichetta in scheda._etichette(CardLibrary.build("picche_c11")):
		assert_false(etichetta.contains(":"), "%s è roba da filtri, non da scheda" % etichetta)


func test_ogni_carta_del_gioco_ha_almeno_un_etichetta() -> void:
	# Una riga vuota sotto il nome è un buco che si nota; e una carta senza
	# etichette è anche una carta che nessun bonus può raggiungere.
	for id in CardLibrary.pool_ids():
		var card := CardLibrary.build(id)
		assert_false(scheda._etichette(card).is_empty(), "%s non ha nessuna etichetta" % id)
