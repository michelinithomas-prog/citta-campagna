extends TestCase
## Quello che appartiene al **posto** invece che alla carta: i buff di slot, il
## bonus fino a fine battaglia, il debuff sui valori altrui. E i tre modi in cui
## una carta cambia posto senza passare dalla pila: rubata, evoluta, generata.
##
## La regola da difendere è una sola e sta scritta nel nome del file: il buff è
## dello slot. La carta che ci passa ne gode, la carta che se ne va non se lo
## porta dietro.

var duel: Duel


func after_each() -> void:
	if duel != null:
		duel.resolver.clear_handlers()
		duel = null


## Un mazzo che colpisce e basta: le Picche vere si fanno anche male da sole, e
## in un test sul lifesteal il loro costo coprirebbe quello che si vuole vedere.
func _colpo(count: int, danno: int = 5, attesa: float = 2.0) -> Array[Card]:
	var seme := {"id": "colpo", "name": "Colpo", "symbol": "!", "family": "poker",
		"color": "danger", "cooldown": {"base": attesa, "per_value": 0.0},
		"effects": [{"type": "damage", "amount": danno}]}
	var valore := {"id": "n1", "family": "poker", "value": 1, "name": "Uno", "short": "1"}
	var out: Array[Card] = []
	for i in count:
		out.append(Card.new(seme, valore))
	return out


func _deck(card_id: String, count: int) -> Array[Card]:
	var out: Array[Card] = []
	for i in count:
		out.append(CardLibrary.build(card_id))
	return out


func _side(name_text: String, cards: Array[Card], config: Dictionary = {}) -> Side:
	return Side.new(name_text, cards, RngStream.new(7), config)


func _duello(mine: Side, theirs: Side) -> Duel:
	duel = Duel.new(mine, theirs, RngStream.new(7), 0.05)
	return duel


# --- buff di slot --------------------------------------------------------

func test_il_buff_potenzia_la_carta_che_sta_in_quel_posto() -> void:
	var mine := _side("io", _deck("picche_c5", 20), {"hp": 100, "is_player": true})
	_duello(mine, _side("lui", _deck("fiori_c1", 20), {"hp": 100}))

	var prima := mine.board[0].value()
	mine.set_slot_buff(0, {"value_add": 4})
	assert_eq(mine.board[0].value(), prima + 4)
	assert_eq(mine.board[1].value(), prima, "gli altri slot non c'entrano niente")


func test_un_buff_nuovo_cancella_il_vecchio() -> void:
	var mine := _side("io", _deck("picche_c5", 20), {"hp": 100, "is_player": true})
	_duello(mine, _side("lui", _deck("fiori_c1", 20), {"hp": 100}))

	var prima := mine.board[0].value()
	mine.set_slot_buff(0, {"value_add": 4})
	mine.set_slot_buff(0, {"value_add": 1})
	assert_eq(mine.board[0].value(), prima + 1, "vale l'ultimo, non la somma")


func test_il_buff_resta_al_posto_quando_la_carta_se_ne_va() -> void:
	# È il senso della Donna: potenzia lo slot, e ne gode chiunque ci passi.
	var mine := _side("io", _deck("picche_c5", 20), {"hp": 100, "is_player": true})
	_duello(mine, _side("lui", _deck("fiori_c1", 20), {"hp": 100}))

	var prima := mine.board[0].value()
	mine.set_slot_buff(0, {"value_add": 3})
	var vecchia := mine.take_from(0)
	mine.discard(vecchia)
	mine.refill()

	assert_eq(mine.board[0].value(), prima + 3, "la carta nuova eredita il buff del posto")
	assert_eq(vecchia.value(), prima, "e quella che se ne va se lo lascia alle spalle")


func test_il_buff_di_partita_e_quello_di_slot_non_si_cancellano() -> void:
	# Sono due `source` diverse apposta: `remove_source` lavora in blocco, e con
	# una etichetta sola sostituire il buff dello slot cancellerebbe il Re.
	var mine := _side("io", _deck("picche_c5", 20), {"hp": 100, "is_player": true})
	_duello(mine, _side("lui", _deck("fiori_c1", 20), {"hp": 100}))

	var prima := mine.board[0].value()
	mine.add_match_mod("value", StatBlock.FLAT, 2.0)
	mine.set_slot_buff(0, {"value_add": 3})
	mine.set_slot_buff(0, {"value_add": 5})

	assert_eq(mine.board[0].value(), prima + 2 + 5, "il Re resta, il buff vecchio no")
	assert_eq(mine.board[1].value(), prima + 2, "il Re vale su tutta la plancia")


func test_il_buff_di_partita_vale_anche_per_chi_arriva_dopo() -> void:
	var mine := _side("io", _deck("picche_c5", 20), {"hp": 100, "is_player": true})
	_duello(mine, _side("lui", _deck("fiori_c1", 20), {"hp": 100}))

	var prima := mine.board[0].value()
	mine.add_match_mod("value", StatBlock.FLAT, 2.0)
	mine.discard(mine.take_from(0))
	mine.refill()
	assert_eq(mine.board[0].value(), prima + 2, "anche la carta pescata dopo")


func test_il_lifesteal_cura_solo_quello_che_arriva_alla_vita() -> void:
	# L'avversario cura sé stesso e basta: se portasse scudo se lo rifarebbe più
	# in fretta di quanto il colpo con lifesteal riesca a bucarlo, e il test
	# misurerebbe la sua rigenerazione invece del lifesteal.
	# Anche l'avversario deve stare fermo: col tema dei numeri perfino un Asso di
	# Cuori porta un danno, e cinque di quelli coprirebbero il lifesteal.
	var mine := _side("io", _colpo(20), {"hp": 100, "is_player": true})
	var theirs := _side("lui", _colpo(30, 0, 60.0), {"hp": 300, "shield": 40})
	_duello(mine, theirs)
	mine.take_damage(40)
	mine.set_slot_buff(0, {"lifesteal": 1.0})

	var ferito := mine.hp
	duel.clock.advance_seconds(4.0)
	assert_eq(mine.hp, ferito, "contro uno scudo pieno il lifesteal non cura niente")

	theirs.purse.set_amount(Side.SHIELD, 0.0)
	duel.clock.advance_seconds(8.0)
	assert_gt(mine.hp, ferito, "caduto lo scudo, la vita rubata arriva")


# --- debuff sui valori altrui --------------------------------------------

func test_indebolire_smorza_le_carte_avversarie_in_plancia() -> void:
	var theirs := _side("lui", _deck("spade_r8", 20), {"hp": 100})
	_duello(_side("io", _deck("fiori_c1", 20), {"hp": 100, "is_player": true}), theirs)

	var prima := theirs.board[0].value()
	for card in theirs.cards_on_board():
		card.stats.add_mod("value", StatBlock.FLAT, -3.0, Card.MOD_BATTLE)
	assert_eq(theirs.board[0].value(), prima - 3)

	# Il debuff è un colpo al presente: chi arriva dopo lo trova già passato.
	theirs.discard(theirs.take_from(0))
	theirs.refill()
	assert_eq(theirs.board[0].value(), prima, "la carta nuova non eredita l'indebolimento")


# --- carte che cambiano posto --------------------------------------------

func test_rubare_toglie_la_carta_all_avversario_e_la_mette_al_proprio_posto() -> void:
	var cards := _deck("picche_c1", 20)
	for card in cards:
		card.add_seal({"id": "ladro", "extra_effects": [{"type": "steal"}]})
	var mine := _side("io", cards, {"hp": 300, "is_player": true})
	var theirs := _side("lui", _deck("spade_r10", 20), {"hp": 300})
	_duello(mine, theirs)

	var scartate_prima := theirs.pile.discarded()
	var rimaste_prima := theirs.pile.remaining()
	duel.clock.advance_seconds(3.0)

	assert_eq(mine.board[0].suit_id, "spade", "la carta rubata occupa lo slot del ladro")
	assert_lt(theirs.pile.remaining(), rimaste_prima, "la vittima ha dovuto pescare")
	assert_eq(theirs.pile.discarded(), scartate_prima, "e la carta rubata non è finita nei suoi scarti")


func test_chi_riceve_una_carta_avvisa_la_schermata() -> void:
	# Rubare ed evolvere non svuotano mai lo slot: senza `slot_filled` la
	# schermata resterebbe a mostrare la carta di prima per tutta la battaglia.
	var mine := _side("io", _deck("picche_c1", 20), {"hp": 100, "is_player": true})
	var avvisi := [0]
	mine.slot_filled.connect(func(_slot: int, _card: Card) -> void: avvisi[0] += 1)

	mine.put_in(0, CardLibrary.build("spade_r10"))
	assert_eq(avvisi[0], 1, "put_in deve emettere slot_filled")
	assert_eq(mine.board[0].suit_id, "spade")


func test_una_carta_che_evolve_finisce_negli_scarti_al_livello_dopo() -> void:
	# L'evoluzione è una proprietà del valore. Qui la si simula con un valore
	# finto che dichiara di crescere: il meccanismo è lo stesso dei gaiofanamon.
	var suit := Content.entry("suits", "picche")
	var cards: Array[Card] = []
	for i in 20:
		cards.append(Card.new(suit, {
			"id": "c2", "family": "poker", "value": 2, "short": "2",
			"name": "Due", "evolves_to": "c9",
		}))
	var mine := _side("io", cards, {"hp": 300, "is_player": true})
	_duello(mine, _side("lui", _deck("fiori_c1", 40), {"hp": 300}))

	duel.clock.advance_seconds(4.0)
	assert_gt(mine.pile.discarded(), 0, "qualcuna deve essersi attivata")
	assert_eq(mine.pile.discard_pile[0].rank_id, "c9",
		"negli scarti ci deve finire la versione cresciuta, non quella di prima")


func test_una_carta_evoluta_si_porta_dietro_sigilli_e_passivi() -> void:
	var suit := Content.entry("suits", "picche")
	var carta := Card.new(suit, {
		"id": "c2", "family": "poker", "value": 2, "short": "2",
		"name": "Due", "evolves_to": "c9",
	})
	carta.add_seal(Content.entry("seals", "affilato"))
	carta.stats.add_mod("value", StatBlock.FLAT, 2.0, "run")
	carta.cooldown_scale = 0.5

	var mine := _side("io", [carta], {"hp": 300, "is_player": true})
	_duello(mine, _side("lui", _deck("fiori_c1", 40), {"hp": 300}))
	var evoluta := duel._evolvi(mine.board[0])

	assert_not_null(evoluta)
	assert_eq(evoluta.rank_id, "c9")
	assert_true(evoluta.has_seal("affilato"), "i sigilli restano attaccati alla creatura")
	assert_almost(evoluta.cooldown_scale, 0.5, 0.001, "e il ritmo della run pure")
	assert_eq(evoluta.stats.mods_from("run").size(), 1, "i passivi della run non si perdono")


# --- il mazzo che si muove -----------------------------------------------

func test_scartare_dalla_cima_assottiglia_il_mazzo_ma_non_uccide_subito() -> void:
	var theirs := _side("lui", _deck("fiori_c1", 20), {"hp": 100})
	theirs.begin()
	var prima := theirs.pile.remaining()

	assert_eq(theirs.pile.mill(3), 3)
	assert_eq(theirs.pile.remaining(), prima - 3)
	assert_eq(theirs.pile.discarded(), 3)
	assert_false(theirs.is_out, "il conto arriva quando dovrà rimpiazzare, non ora")


func test_recuperare_rimette_in_fondo_alla_pila() -> void:
	var mine := _side("io", _deck("picche_c5", 8), {"hp": 100, "is_player": true})
	mine.begin()
	mine.pile.mill(3)

	var prima := mine.pile.remaining()
	var tornate := mine.pile.recover(RngStream.new(3), 2)
	assert_eq(tornate.size(), 2)
	assert_eq(mine.pile.remaining(), prima + 2, "il deck-out si allontana")
	assert_eq(mine.pile.discarded(), 1)

	# In fondo: prima escono tutte le altre.
	for i in prima:
		mine.pile.draw()
	assert_eq(mine.pile.draw().id, tornate[1].id, "le recuperate escono per ultime")


func test_recuperare_a_scarti_vuoti_non_inventa_carte() -> void:
	var mine := _side("io", _deck("picche_c5", 8), {"hp": 100, "is_player": true})
	assert_eq(mine.pile.recover(RngStream.new(3), 3).size(), 0)


func test_generare_una_carta_la_mette_in_cima() -> void:
	var mine := _side("io", _deck("picche_c5", 8), {"hp": 100, "is_player": true})
	var prima := mine.pile.remaining()
	mine.pile.insert_top(CardLibrary.build("coppe_r10"))

	assert_eq(mine.pile.remaining(), prima + 1)
	assert_eq(mine.pile.draw().id, "coppe_r10", "una carta nata adesso deve poter scendere in campo")


func test_chi_lascia_lo_slot_dice_anche_perche() -> void:
	# Per la simulazione scartare, evolvere e farsi rubare sono lo stesso gesto.
	# Per chi guarda no, ed è per questo che il motivo viaggia col segnale.
	var suit := Content.entry("suits", "picche")
	var cards: Array[Card] = []
	for i in 20:
		cards.append(Card.new(suit, {
			"id": "c2", "family": "poker", "value": 2, "short": "2",
			"name": "Due", "evolves_to": "c9",
		}))
	var mine := _side("io", cards, {"hp": 300, "is_player": true})
	_duello(mine, _side("lui", _colpo(40, 0, 60.0), {"hp": 300}))

	var motivi := {}
	duel.card_left.connect(func(_s: Side, _slot: int, _c: Card, motivo: String) -> void:
		motivi[motivo] = true
	)
	duel.clock.advance_seconds(4.0)

	assert_true(motivi.has(Duel.MOTIVO_EVOLUTA),
		"una carta che cresce di livello deve dirlo: %s" % [motivi.keys()])
