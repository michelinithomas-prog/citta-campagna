extends TestCase
## I mazzi che si svelano strada facendo.
##
## One e Gaiofanamon non esistono per le prime due sfide: né in vetrina né nei
## mazzi degli avversari. È una regola che si può rompere da tre punti diversi —
## la bottega, la ricetta dell'avversario, i pesi di default quando la ricetta
## resta vuota — e quello che segue tiene chiusi tutti e tre.

const NASCOSTI := ["one", "gaiofanamon"]


func _run_con_vittorie(quante: int) -> RunState:
	var run := RunState.new(RngStream.new(7))
	run.tutorial = false
	run.wins = quante
	return run


func test_i_mazzi_nuovi_sono_dichiarati_nei_dati() -> void:
	# Se qualcuno toglie `reveal_after_wins` dai JSON, il resto di questo file
	# continuerebbe a passare mentendo: qui si controlla la premessa.
	for id in NASCOSTI:
		assert_true(Content.has("families", id), "manca la famiglia %s" % id)
		assert_gt(int(Content.entry("families", id).get("reveal_after_wins", 0)), 0,
			"%s non è più marcato come mazzo da svelare" % id)


func test_prima_della_terza_bottega_la_vetrina_non_li_offre() -> void:
	var run := _run_con_vittorie(0)
	var market := Market.new(RngStream.new(3))
	# Trenta giri: una vetrina sola potrebbe non pescarli per caso.
	for giro in 30:
		market.roll(1, run)
		for card in market.card_offers:
			assert_false(card.family in NASCOSTI,
				"la bottega ha offerto %s (%s) prima che fosse svelato" % [card.id, card.family])


func test_dalla_terza_bottega_in_poi_compaiono() -> void:
	var run := _run_con_vittorie(2)
	var market := Market.new(RngStream.new(3))
	var visti := {}
	for giro in 60:
		market.roll(5, run)
		for card in market.card_offers:
			visti[card.family] = true
	for id in NASCOSTI:
		assert_true(visti.has(id), "%s non compare mai in vetrina nemmeno dopo la rivelazione" % id)


func test_l_avversario_non_gioca_quello_che_non_hai_ancora_visto() -> void:
	var run := _run_con_vittorie(0)
	for entry in Content.list("opponents"):
		var mazzo := CardLibrary.generate(RngStream.new(11), run.ricetta_svelata(entry))
		for card in mazzo:
			assert_false(card.family in NASCOSTI,
				"%s scende in campo con %s prima della rivelazione" % [entry.get("id"), card.family])


func test_una_ricetta_di_soli_mazzi_nascosti_non_resta_senza_carte() -> void:
	# Il caso che romperebbe tutto in silenzio: se `ricetta_svelata` svuotasse i
	# pesi, `random_card` ricadrebbe sui default — **compresi i nascosti**, cioè
	# proprio le carte che stiamo tenendo da parte.
	var run := _run_con_vittorie(0)
	var ricetta := {"deck_size": 12, "weights": {"one": 1.0, "gaiofanamon": 1.0}, "value_range": [1, 6]}
	var mazzo := CardLibrary.generate(RngStream.new(5), run.ricetta_svelata(ricetta))

	assert_eq(mazzo.size(), 12, "la ricetta ripulita ha prodotto un mazzo della misura sbagliata")
	for card in mazzo:
		assert_false(card.family in NASCOSTI, "è tornato dentro %s dai pesi di default" % card.family)


func test_dopo_la_rivelazione_la_ricetta_torna_quella_scritta() -> void:
	var run := _run_con_vittorie(2)
	var ricetta := {"weights": {"poker": 1.0, "one": 3.0}}
	assert_eq(run.ricetta_svelata(ricetta)["weights"], {"poker": 1.0, "one": 3.0},
		"a rivelazione avvenuta la ricetta non va più toccata")
