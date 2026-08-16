extends TestCase
## Il duello: determinismo, le due sconfitte, scudo, ritmo delle attivazioni.

var duel: Duel


func after_each() -> void:
	if duel != null:
		# Gli handler catturano il Duel: senza questo non viene liberato niente.
		duel.resolver.clear_handlers()
		duel = null


# --- costruzione di comodo ----------------------------------------------

func _side(name_text: String, ids: Array, config: Dictionary = {}, seed_value: int = 7) -> Side:
	return Side.new(name_text, CardLibrary.deck_from_ids(ids), RngStream.new(seed_value), config)


func _duel(mine: Side, theirs: Side, seed_value: int = 7) -> Duel:
	return Duel.new(mine, theirs, RngStream.new(seed_value), 0.05)


## Un mazzo di N copie della stessa carta: rende prevedibile il ritmo.
func _same(card_id: String, count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(card_id)
	return out


# --- determinismo --------------------------------------------------------

func test_stesso_seed_stesso_esito() -> void:
	var esiti: Array = []
	for run in 2:
		var mine := _side("io", Cfg.get_value("deck.starting", []), {"hp": 50, "is_player": true}, 42)
		var theirs := _side("lui", _same("picche_c4", 12), {"hp": 40}, 42)
		var d := _duel(mine, theirs, 42)
		d.simulate_to_end()
		esiti.append([d.won, d.reason, d.activations, mine.hp, theirs.hp])
		d.resolver.clear_handlers()
	assert_eq(esiti[0], esiti[1], "stesso seed deve dare esattamente lo stesso duello")


# --- deck-out ------------------------------------------------------------

func test_un_lato_gia_spacciato_perde_al_primo_tick_non_prima() -> void:
	# Con un mazzo più corto della plancia il lato è perduto in partenza. La
	# fine però non deve scattare dentro il costruttore: lì la scena non si è
	# ancora collegata a `ended`, il segnale andrebbe perso e la partita
	# resterebbe ferma sulla schermata di battaglia per sempre.
	var mine := _side("io", _same("picche_c5", 3), {"hp": 50, "is_player": true})
	var theirs := _side("lui", _same("picche_c5", 40), {"hp": 50})
	duel = _duel(mine, theirs)

	assert_false(duel.is_over, "il duello non deve chiudersi dentro Duel.new()")

	var esiti := [0]
	duel.ended.connect(func(_won: bool, _reason: String) -> void: esiti[0] += 1)
	duel.simulate_to_end()

	assert_eq(esiti[0], 1, "chi si collega dopo la costruzione deve sentire la fine")
	assert_false(duel.won)
	assert_eq(duel.reason, Side.REASON_DECKOUT)


func test_finire_le_carte_e_una_sconfitta() -> void:
	# 6 carte innocue contro 30: il primo lato resta senza carte molto prima.
	var mine := _side("io", _same("cuori_c1", 6), {"hp": 100, "is_player": true})
	var theirs := _side("lui", _same("cuori_c1", 30), {"hp": 100})
	duel = _duel(mine, theirs)
	duel.simulate_to_end()

	assert_false(duel.won, "chi finisce le carte perde")
	assert_eq(duel.reason, Side.REASON_DECKOUT)
	assert_eq(mine.hp, 100, "nessuno ha fatto un graffio: la sconfitta è tutta del mazzo")


func test_il_deckout_arriva_dopo_le_attivazioni_previste() -> void:
	# 8 carte, 5 in plancia → 3 nella pila → la quarta attivazione non trova
	# rimpiazzo. L'effetto della quarta parte comunque: l'ultima carta spara.
	var mine := _side("io", _same("cuori_c2", 8), {"hp": 100, "is_player": true})
	var theirs := _side("lui", _same("cuori_c2", 40), {"hp": 100})
	duel = _duel(mine, theirs)

	var mie_attivazioni := [0]
	duel.card_activated.connect(func(side: Side, _slot: int, _card: Card) -> void:
		if side.is_player:
			mie_attivazioni[0] += 1
	)
	duel.simulate_to_end()

	assert_eq(duel.reason, Side.REASON_DECKOUT)
	assert_eq(mie_attivazioni[0], 4, "3 rimpiazzi disponibili, la quarta attivazione è fatale")


func test_l_ultima_carta_fa_comunque_il_suo_effetto() -> void:
	# Sei picche: le prime cinque in plancia, una sola nella pila. Alla seconda
	# attivazione non c'è rimpiazzo, ma il danno deve essere già arrivato.
	var mine := _side("io", _same("picche_c10", 6), {"hp": 100, "is_player": true})
	var theirs := _side("lui", _same("cuori_c1", 60), {"hp": 100})
	duel = _duel(mine, theirs)
	duel.simulate_to_end()

	assert_eq(duel.reason, Side.REASON_DECKOUT)
	assert_lt(theirs.hp, 100, "le carte partite prima del deck-out hanno colpito")


# --- scudo ---------------------------------------------------------------

func test_lo_scudo_assorbe_prima_degli_hp() -> void:
	var side := Side.new("prova", [], RngStream.new(1), {"hp": 30, "shield": 10})
	assert_eq(side.take_damage(4), 0, "sotto lo scudo non passa niente")
	assert_eq(side.shield(), 6)
	assert_eq(side.hp, 30)

	assert_eq(side.take_damage(10), 4, "6 assorbiti, 4 passano")
	assert_eq(side.shield(), 0)
	assert_eq(side.hp, 26)


func test_lo_scudo_non_va_sotto_zero() -> void:
	var side := Side.new("prova", [], RngStream.new(1), {"hp": 30, "shield": 3})
	side.take_damage(100)
	assert_eq(side.shield(), 0)
	assert_eq(side.hp, 0)
	assert_true(side.is_out)
	assert_eq(side.defeat_reason, Side.REASON_HP)


func test_le_carte_scudo_reggono_i_colpi() -> void:
	# cuori_c6 mette scudo a ogni giro; picche_c1 fa un danno scarso. Lo scudo
	# arriva sempre dopo il colpo, quindi i primi passano — ma da lì in poi non
	# entra quasi più niente, e chi difende resta in piedi.
	#
	# Contro le Spade sarebbe un altro discorso: quelle lo scudo lo attraversano.
	var mine := _side("io", _same("cuori_c6", 30), {"hp": 60, "is_player": true})
	var theirs := _side("lui", _same("picche_c1", 30), {"hp": 60})
	duel = _duel(mine, theirs)
	duel.simulate_to_end()
	assert_gt(mine.hp, 30, "dopo la prima raffica lo scudo deve tenere botta")


# --- ritmo ---------------------------------------------------------------

func test_le_carte_partono_al_loro_intervallo() -> void:
	# picche_c1: 2.0 + 1×0.30 = 2.3 secondi, e l'Asso non aggiunge attesa.
	# Cinque in plancia, mazzo profondo: in 4.7 secondi ogni slot è partito due
	# volte.
	var mine := _side("io", _same("picche_c1", 60), {"hp": 500, "is_player": true})
	var theirs := _side("lui", _same("cuori_c1", 200), {"hp": 500})
	duel = _duel(mine, theirs)

	var mie := [0]
	duel.card_activated.connect(func(side: Side, _slot: int, _card: Card) -> void:
		if side.is_player:
			mie[0] += 1
	)
	duel.clock.advance_seconds(4.7)

	assert_eq(mie[0], 10, "5 slot × 2 attivazioni in 4.7 secondi")


func test_la_citta_e_piu_svelta_della_campagna() -> void:
	var citta := _side("citta", _same("picche_c6", 60), {"hp": 500, "is_player": true})
	var campagna := _side("campagna", _same("spade_r6", 60), {"hp": 500})
	duel = _duel(citta, campagna)

	var conteggi := {"citta": 0, "campagna": 0}
	duel.card_activated.connect(func(side: Side, _slot: int, _card: Card) -> void:
		conteggi[side.display_name] += 1
	)
	duel.clock.advance_seconds(20.0)

	assert_gt(conteggi["citta"], conteggi["campagna"], "le carte di città scattano più spesso")


# --- effetti di base -----------------------------------------------------

func test_le_carte_denari_riempiono_la_borsa() -> void:
	var mine := _side("io", _same("denari_r6", 20), {"hp": 200, "is_player": true})
	var theirs := _side("lui", _same("cuori_c1", 20), {"hp": 200})
	duel = _duel(mine, theirs)
	duel.simulate_to_end()
	assert_gt(mine.gold(), 0, "denari_r6 deve aver fruttato oro")


func test_la_cura_non_supera_il_massimo() -> void:
	var side := Side.new("prova", [], RngStream.new(1), {"hp": 30})
	side.take_damage(10)
	side.heal(100)
	assert_eq(side.hp, 30)


# --- l'equilibrio del gioco ---------------------------------------------

## Simula il mazzo iniziale contro un avversario, su più seed.
func _prova_avversario(opponent_id: String, seeds: int) -> Dictionary:
	var esiti := {"vinte": 0, "totali": 0, "ragioni": {}, "durata": 0.0}
	var recipe := Content.entry("opponents", opponent_id)

	for seed_value in range(1, seeds + 1):
		var mine := _side("io", Cfg.get_value("deck.starting", []),
			{"hp": Cfg.get_int("player.hp", 45), "is_player": true}, seed_value)
		var theirs := Side.new(
			String(recipe.get("name", "")),
			CardLibrary.generate(RngStream.new(seed_value), recipe),
			RngStream.new(seed_value + 500),
			{"hp": int(recipe.get("hp", 40)), "shield": int(recipe.get("shield", 0))}
		)
		var d := _duel(mine, theirs, seed_value)
		d.simulate_to_end()

		esiti["totali"] += 1
		esiti["durata"] += d.elapsed
		if d.won:
			esiti["vinte"] += 1
		esiti["ragioni"][d.reason] = int(esiti["ragioni"].get(d.reason, 0)) + 1
		d.resolver.clear_handlers()

	return esiti


## Il primo e l'ultimo della fila. Chiederli alla lista invece di scriverne l'id
## significa che ribattezzare un avversario non fa diventare rosso un test che
## parla d'altro — ed è successo, quando "round8" è diventato "Il Professore".
func _primo_avversario() -> String:
	var lista: Array = Content.list("opponents")
	return String(lista[0].get("id", "")) if not lista.is_empty() else ""


func _ultimo_avversario() -> String:
	var lista: Array = Content.list("opponents")
	return String(lista[-1].get("id", "")) if not lista.is_empty() else ""


func test_entrambe_le_sconfitte_esistono_nella_run() -> void:
	# Il test che sorveglia il bilanciamento. Se una sola delle due sconfitte
	# capitasse davvero, metà del gioco sarebbe finta: le carte lente non
	# avrebbero motivo di esistere, o non l'avrebbero quelle veloci.
	var ragioni := {}
	for entry in Content.list("opponents"):
		var esiti := _prova_avversario(String(entry.get("id", "")), 5)
		for reason in esiti["ragioni"]:
			ragioni[reason] = int(ragioni.get(reason, 0)) + int(esiti["ragioni"][reason])

	assert_true(ragioni.has(Side.REASON_HP), "nessun duello si chiude per HP: %s" % ragioni)
	assert_true(ragioni.has(Side.REASON_DECKOUT), "nessun duello si chiude per esaurimento: %s" % ragioni)


func test_il_primo_avversario_si_batte_col_mazzo_di_partenza() -> void:
	# Chi prova il gioco allo stand deve vincere il primo round senza sapere
	# ancora niente. Se questo si rompe, la curva è da rifare dall'inizio.
	var esiti := _prova_avversario(_primo_avversario(), 10)
	assert_gt(esiti["vinte"], 5, "il primo avversario vinto solo %d volte su 10" % esiti["vinte"])


func test_l_ultimo_avversario_non_e_una_passeggiata() -> void:
	# Col mazzo di partenza, senza aver comprato niente, il Signore deve vincere
	# quasi sempre: è quello che rende necessario costruire il mazzo.
	var esiti := _prova_avversario(_ultimo_avversario(), 10)
	assert_lt(esiti["vinte"], 4, "l'ultimo avversario vinto %d volte su 10 col mazzo base" % esiti["vinte"])


func test_le_battaglie_durano_abbastanza_da_essere_guardate() -> void:
	var esiti := _prova_avversario(_primo_avversario(), 5)
	var media: float = esiti["durata"] / float(esiti["totali"])
	assert_gt(media, 6.0, "battaglie da %.1fs: si finisce prima di capire cosa succede" % media)
	assert_lt(media, 45.0, "battaglie da %.1fs: troppo lunghe da guardare" % media)


func test_nessuna_battaglia_finisce_per_tempo() -> void:
	# `Duel.MAX_SECONDS` è una rete anti-loop, non un modo di vincere: chi ci
	# arriva vede una partita che si chiude da sola dopo tre minuti senza che
	# nessuno abbia fatto niente. È la spia delle carte che rimettono in mazzo
	# quello che hanno appena scartato: finché sono poche il mazzo finisce lo
	# stesso, quando diventano tante la battaglia non finisce più.
	var per_tempo := 0
	var dove: Array[String] = []
	for entry in Content.list("opponents"):
		var id := String(entry.get("id", ""))
		var esiti := _prova_avversario(id, 5)
		var quante := int(esiti["ragioni"].get("tempo", 0))
		if quante > 0:
			per_tempo += quante
			dove.append("%s ×%d" % [id, quante])

	assert_eq(per_tempo, 0, "%d battaglie chiuse allo scadere del tempo: %s" % [per_tempo, dove])
