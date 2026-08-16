extends TestCase
## La catena di One: cresce quando la carta che entra somiglia a quella che se
## n'è andata — stesso colore o stesso numero — e da lì in poi tutto il lato
## colpisce, cura e ripara di più.
##
## Non cala mai da sola. L'unica cosa che la spegne è il Blocco, e il Blocco nel
## mazzo ci finisce in un modo solo: ce l'hai messo tu giocando un Pesca Quattro.
## È quel patto — quattro anelli adesso, il conto più tardi — a rendere la carta
## una scelta invece di un regalo.

var duel: Duel


func after_each() -> void:
	if duel != null:
		duel.resolver.clear_handlers()
		duel = null


## Un mazzo di carte ferme: la catena si prova mettendo e togliendo carte a
## mano, non aspettando che il caso faccia uscire quella giusta.
func _fermo(count: int = 30) -> Array[Card]:
	var seme := {"id": "fermo", "name": "Fermo", "symbol": "·", "family": "poker",
		"color": "secondary", "cooldown": {"base": 90.0, "per_value": 0.0}, "effects": []}
	var valore := {"id": "f0", "family": "poker", "value": 1, "name": "Fermo", "short": "-"}
	var out: Array[Card] = []
	for i in count:
		out.append(Card.new(seme, valore))
	return out


func _lato(nome: String, config: Dictionary = {}) -> Side:
	return Side.new(nome, _fermo(), RngStream.new(7), config)


func _duello(mine: Side, theirs: Side) -> Duel:
	duel = Duel.new(mine, theirs, RngStream.new(7), 0.05)
	return duel


## Toglie quello che c'è nello slot e ci mette quella carta: è il gesto con cui
## la catena si misura, senza dipendere da come è stato mescolato il mazzo.
func _sostituisci(side: Side, slot: int, uscita: Card, entrata: Card) -> void:
	side.board[slot] = uscita
	side.take_from(slot)
	side.put_in(slot, entrata)


func _carta(id: String) -> Card:
	return CardLibrary.build(id)


# --- quando la catena cresce ---------------------------------------------

func test_lo_stesso_colore_allunga_la_catena() -> void:
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("rosso_o3"), _carta("rosso_o7"))
	assert_eq(mine.combo, 1, "due carte rosse di fila fanno catena")


func test_lo_stesso_numero_allunga_la_catena() -> void:
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("rosso_o7"), _carta("blu_o7"))
	assert_eq(mine.combo, 1, "due Sette di colore diverso fanno catena lo stesso")


func test_colori_e_numeri_diversi_non_fanno_niente() -> void:
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("rosso_o3"), _carta("blu_o7"))
	assert_eq(mine.combo, 0, "niente in comune, niente catena")


func test_le_rosse_del_poker_entrano_nella_catena_ma_non_la_fanno_partire() -> void:
	# La catena è di One, e **la fa partire One**: conta il mazzo della carta che
	# esce dallo slot. Chi entra può arrivare da dove vuole — Cuori e Quadri sono
	# rosse quanto il Rosso di One, ed è la ragione per cui un mazzo di catena se
	# le tiene.
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("rosso_o3"), _carta("cuori_c7"))
	assert_eq(mine.combo, 1, "una Cuori continua una catena rossa")

	# Senza questo vincolo la catena partiva da sola nel primo round: il Baro
	# gioca poker, il poker ha due semi rossi, e due rosse di fila bastavano.
	# Trentacinque battaglie su quaranta con una meccanica ancora mai vista.
	_sostituisci(mine, 1, _carta("cuori_c4"), _carta("quadri_c9"))
	assert_eq(mine.combo, 1, "due rosse di poker da sole non fanno partire niente")


func test_le_nere_del_poker_restano_fuori() -> void:
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("rosso_o3"), _carta("picche_c7"))
	assert_eq(mine.combo, 0, "il nero non è uno dei colori di One")


func test_il_numero_resta_in_casa() -> void:
	# Due Sette di poker sono una coincidenza, non una catena: il numero lega
	# solo dentro il mazzo che ha la catena per tema.
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("picche_c7"), _carta("fiori_c7"))
	assert_eq(mine.combo, 0)


func test_il_cambia_colore_sta_bene_con_tutti() -> void:
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("verde_o4"), _carta("cambiacolore_w0"))
	assert_eq(mine.combo, 1, "il Cambia Colore continua qualunque catena")

	_sostituisci(mine, 1, _carta("cambiacolore_w0"), _carta("giallo_o9"))
	assert_eq(mine.combo, 2, "e la fa continuare anche a chi arriva dopo di lui")


func test_la_catena_ha_un_tetto() -> void:
	var mine := _lato("io", {"is_player": true})
	var tetto := maxi(Cfg.get_int("battle.combo_cap", 10), 1)
	mine.add_combo(tetto + 20)
	assert_eq(mine.combo, tetto, "la catena non può crescere all'infinito")


# --- cosa fa la catena ----------------------------------------------------

func test_la_catena_moltiplica_colpi_cure_e_scudi() -> void:
	var passo := Cfg.get_float("battle.combo_step", 0.10)
	var mine := _lato("io", {"is_player": true})
	assert_almost(mine.combo_multiplier(), 1.0, 0.001, "senza catena non moltiplica niente")

	mine.add_combo(4)
	assert_almost(mine.combo_multiplier(), 1.0 + 4 * passo, 0.001)


func test_con_la_catena_la_stessa_carta_colpisce_di_piu() -> void:
	# La catena non è un potere del mazzo One: è uno stato di chi la tiene in
	# piedi, e vale per **tutte** le sue carte.
	var colpi: Array[Card] = []
	for i in 20:
		colpi.append(_carta("picche_c10"))
	var mine := Side.new("io", colpi, RngStream.new(7), {"hp": 300, "is_player": true})
	var theirs := _lato("lui", {"hp": 3000})
	_duello(mine, theirs)

	duel.clock.advance_seconds(6.0)
	var senza := 3000 - theirs.hp
	assert_gt(senza, 0, "qualche colpo deve essere arrivato")

	mine.add_combo(8)
	var prima := theirs.hp
	duel.clock.advance_seconds(6.0)
	assert_gt(prima - theirs.hp, senza, "con la catena gli stessi colpi devono fare più male")


# --- il Blocco ------------------------------------------------------------

func test_il_blocco_spegne_la_catena_entrando_in_campo() -> void:
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))
	mine.add_combo(6)

	_sostituisci(mine, 0, _carta("rosso_o3"), _carta("blocco_b0"))
	assert_eq(mine.combo, 0, "il Blocco spegne la catena quando entra, non quando parte")


func test_il_blocco_spegne_anche_la_catena_che_ha_appena_allungato() -> void:
	# Entrando dopo una corrispondenza il Blocco la trova più lunga di un anello,
	# e la spegne lo stesso: non c'è un momento buono per farlo entrare.
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))
	mine.add_combo(3)

	_sostituisci(mine, 0, _carta("cambiacolore_w0"), _carta("blocco_b0"))
	assert_eq(mine.combo, 0)


func test_il_pesca_quattro_si_porta_dietro_il_suo_blocco() -> void:
	var carte: Array[Card] = []
	for i in 12:
		carte.append(_carta("pescaquattro_q0"))
	var mine := Side.new("io", carte, RngStream.new(7), {"hp": 300, "is_player": true})
	_duello(mine, _lato("lui", {"hp": 3000}))

	# Un mazzo di soli Pesca Quattro si allaga di Blocchi da solo, quindi non si
	# guarda dove finisce la catena: si guarda che parta, e che il conto resti
	# nel mazzo.
	var massimo := [0]
	mine.combo_changed.connect(func(v: int) -> void: massimo[0] = maxi(massimo[0], v))
	# Il Pesca Quattro è una bomba e si fa aspettare: quindici secondi buoni.
	duel.clock.advance_seconds(CardLibrary.build("pescaquattro_q0").interval() + 1.0)
	assert_gt(massimo[0], 3, "il Pesca Quattro allunga la catena di quattro anelli")

	var blocchi := 0
	for gruppo in [mine.pile.draw_pile, mine.pile.discard_pile, mine.board]:
		for card in gruppo:
			if card != null and card.suit_id == "blocco":
				blocchi += 1
	assert_gt(blocchi, 0, "e mette nel tuo mazzo il Blocco che te la spegnerà")


func test_il_blocco_non_si_compra() -> void:
	assert_false("blocco_b0" in CardLibrary.pool_ids(),
		"nel mazzo ci va in un modo solo: giocando un Pesca Quattro")


func test_lo_zero_colpisce_come_un_dieci_ma_lega_come_uno_zero() -> void:
	# Un Dieci di One non esiste e non deve esistere: lo Zero fa il suo lavoro.
	assert_false("rosso_o10" in CardLibrary.all_ids(), "il Dieci di One non deve esistere")

	var zero := CardLibrary.build("rosso_o0")
	assert_eq(int(zero.stats.get_base("value")), 10, "colpisce come un Dieci")
	assert_eq(zero.short, "0", "ma sulla carta c'è scritto zero")

	# E per la catena vale zero: lega con gli altri zeri, non con i valori alti.
	var mine := _lato("io", {"is_player": true})
	_duello(mine, _lato("lui"))

	_sostituisci(mine, 0, _carta("rosso_o0"), _carta("giallo_o0"))
	assert_eq(mine.combo, 1, "zero con zero fa catena")

	_sostituisci(mine, 1, _carta("rosso_o0"), _carta("giallo_o9"))
	assert_eq(mine.combo, 1, "uno Zero non lega con un Nove per via del valore che vale")


func test_la_catena_parte_solo_da_una_carta_di_one() -> void:
	# Il verso conta: è il mazzo di **chi esce** a decidere se la catena esiste.
	var uno := CardLibrary.build("rosso_o5")
	var cuori := CardLibrary.build("cuori_c5")

	assert_true(cuori.combos_with(uno), "una Cuori che entra dopo un Rosso di One aggancia")
	assert_false(uno.combos_with(cuori), "un Rosso di One che entra dopo una Cuori no")
