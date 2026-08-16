extends TestCase
## Le proporzioni della bottega, misurate sui dati veri.
##
## L'economia ha un'unità: **2 oro**. Su quella si appoggia tutto il resto.
##
##   innesto : carta : reliquia  =  1 : 2 : 6   ->   2 : 4 : 12 oro di media
##
## Da lì scendono gli altri numeri: `shop.gold_per_round` vale due carte (8 oro),
## e `shop.starting_gold` fa partire il giocatore con lo stesso budget, così il
## primo accesso alla bottega non è più povero degli altri.
##
## Le medie si calcolano sul catalogo intero — tutte le 92 carte, tutti gli
## innesti, tutte le reliquie — non su una vetrina estratta a caso: la vetrina
## cambia a ogni seed, il listino no.
##
## Le soglie sono larghe (±25%) apposta. Questi sono rapporti, non uguaglianze:
## servono ad accorgersi che un prezzo è finito fuori scala, non a congelare il
## bilanciamento. Se un test qui diventa rosso, la domanda è "quale prezzo è
## scappato", non "come allargo la tolleranza".

## Quanto può scostarsi una media dal suo bersaglio prima che sia un errore.
const TOLLERANZA := 0.25

## L'unità di conto dell'economia: il prezzo di un innesto.
const UNITA := 2.0

var market: Market


func before_each() -> void:
	# Nessuna RunState: i prezzi vanno letti a listino, senza gli sconti delle
	# reliquie. Con `_run` a null il Market non applica nessun moltiplicatore.
	market = Market.new(RngStream.new(7))


func after_each() -> void:
	market = null


# --- strumenti -----------------------------------------------------------

func _media(valori: Array) -> float:
	if valori.is_empty():
		return 0.0
	var somma := 0.0
	for v in valori:
		somma += float(v)
	return somma / float(valori.size())


## Il prezzo di ogni carta che il gioco sa costruire, non solo di quelle in
## vetrina: la vetrina è un campione, il catalogo è la verità.
func _prezzi_carte() -> Array:
	var out: Array = []
	for card_id in CardLibrary.pool_ids():
		var card := CardLibrary.build(card_id)
		if card != null:
			out.append(market.card_price(card))
	return out


func _prezzi_innesti() -> Array:
	var out: Array = []
	for entry in Content.list("seals"):
		var seal: Dictionary = entry
		out.append(market.seal_price(seal))
	return out


func _prezzi_reliquie() -> Array:
	var out: Array = []
	for entry in Content.list("relics"):
		var relic: Dictionary = entry
		out.append(market.relic_price(relic))
	return out


## Un rapporto entro la tolleranza, con un messaggio che dice i numeri veri:
## quando salta si deve capire di quanto senza rileggere il JSON.
func _vicino(ottenuto: float, atteso: float, cosa: String) -> void:
	var basso := atteso * (1.0 - TOLLERANZA)
	var alto := atteso * (1.0 + TOLLERANZA)
	var msg := "%s: atteso ~%.2f (fra %.2f e %.2f), ottenuto %.2f" % [cosa, atteso, basso, alto, ottenuto]
	assert_gt(ottenuto, basso, msg)
	assert_lt(ottenuto, alto, msg)


# --- la proporzione 1 : 2 : 6 -------------------------------------------

func test_un_innesto_costa_l_unita_di_conto() -> void:
	_vicino(_media(_prezzi_innesti()), UNITA, "prezzo medio degli innesti")


func test_una_carta_costa_come_due_innesti() -> void:
	# È il numero da cui dipende tutto il resto della bottega: se la media delle
	# carte scivola, `gold_per_round` non compra più due carte.
	_vicino(_media(_prezzi_carte()), UNITA * 2.0, "prezzo medio delle carte")


func test_una_reliquia_costa_come_sei_innesti() -> void:
	_vicino(_media(_prezzi_reliquie()), UNITA * 6.0, "prezzo medio delle reliquie")


func test_un_innesto_vale_mezza_carta() -> void:
	var carte := _media(_prezzi_carte())
	assert_gt(carte, 0.0, "nessuna carta costruibile: il catalogo è vuoto")
	_vicino(_media(_prezzi_innesti()) / carte, 0.5, "innesti / carte")


func test_una_reliquia_vale_tre_carte() -> void:
	var carte := _media(_prezzi_carte())
	assert_gt(carte, 0.0, "nessuna carta costruibile: il catalogo è vuoto")
	_vicino(_media(_prezzi_reliquie()) / carte, 3.0, "reliquie / carte")


# --- l'oro del round -----------------------------------------------------

func test_l_oro_di_un_round_vale_due_carte_medie() -> void:
	var carte := _media(_prezzi_carte())
	assert_gt(carte, 0.0)
	var quante := float(Cfg.get_int("shop.gold_per_round", 8)) / carte
	_vicino(quante, 2.0, "carte medie comprabili con l'oro di un round")


func test_si_parte_con_il_budget_di_un_round() -> void:
	# Il primo accesso alla bottega non deve essere più povero degli altri:
	# altrimenti il round 1 si gioca con il mazzo di partenza e basta.
	assert_eq(Cfg.get_int("shop.starting_gold", 0), Cfg.get_int("shop.gold_per_round", 0))


func test_con_l_oro_di_partenza_si_comprano_davvero_due_carte() -> void:
	# La prova sul campo, non sulla media: vetrina del round 1, oro di partenza,
	# si compra la carta più cara alla portata finché si può.
	var run := RunState.new(RngStream.new(11))
	market.roll(1, run)

	var comprate := 0
	while comprate < 2:
		var migliore := -1
		var prezzo := 0
		for i in market.card_offers.size():
			var costo := market.card_price(market.card_offers[i])
			if costo <= run.gold() and costo > prezzo:
				migliore = i
				prezzo = costo
		if migliore < 0 or market.buy_card(migliore, run) == null:
			break
		comprate += 1

	assert_eq(comprate, 2, "con %d oro non sono uscite due carte dalla vetrina" %
		Cfg.get_int("shop.starting_gold", 0))


# --- le forbici di prezzo ------------------------------------------------

func test_gli_innesti_stanno_fra_uno_e_tre_oro() -> void:
	for entry in Content.list("seals"):
		var seal: Dictionary = entry
		var costo := int(seal.get("cost", 0))
		var id := String(seal.get("id", ""))
		assert_gt(costo, 0, "l'innesto %s è gratis" % id)
		assert_lt(costo, 4, "l'innesto %s costa %d: fuori dalla forbice 1-3" % [id, costo])


func test_le_reliquie_stanno_fra_dieci_e_quindici_oro() -> void:
	for entry in Content.list("relics"):
		var relic: Dictionary = entry
		var costo := int(relic.get("cost", 0))
		var id := String(relic.get("id", ""))
		assert_gt(costo, 9, "la reliquia %s costa %d: sotto la forbice 10-15" % [id, costo])
		assert_lt(costo, 16, "la reliquia %s costa %d: sopra la forbice 10-15" % [id, costo])


func test_la_carta_piu_cara_non_e_una_reliquia_travestita() -> void:
	# Se una carta costasse come una reliquia, la scelta in bottega sparirebbe.
	var prezzi := _prezzi_carte()
	var massimo := 0.0
	for p in prezzi:
		massimo = maxf(massimo, float(p))
	assert_lt(massimo, _media(_prezzi_reliquie()), "la carta più cara supera la reliquia media")


# --- il catalogo deve reggere la vetrina larga --------------------------

func test_ci_sono_abbastanza_innesti_per_riempire_la_vetrina() -> void:
	# Il Market estrae senza ripetizioni, quindi con quattro innesti esatti la
	# vetrina si riempirebbe lo stesso — sempre con gli stessi quattro. Il
	# catalogo deve essere abbastanza largo da cambiare faccia a ogni round.
	var caselle := Cfg.get_int("shop.seal_offers", 4)
	assert_gt(Content.count("seals"), caselle * 3 - 1,
		"%d innesti per %d caselle: la vetrina si ripete di continuo" %
		[Content.count("seals"), caselle])


func test_ci_sono_abbastanza_reliquie_per_tutta_la_run() -> void:
	# Le reliquie comprate escono dal mazzo delle offerte: il catalogo deve
	# reggere anche quando il giocatore ne ha già in tasca mezza dozzina.
	var caselle := Cfg.get_int("shop.relic_offers", 4)
	assert_gt(Content.count("relics"), caselle * 3 - 1,
		"%d reliquie per %d caselle: a fine run la vetrina resta a metà" %
		[Content.count("relics"), caselle])


func test_gli_innesti_non_si_chiamano_piu_innesto_qualcosa() -> void:
	# In una schermata intitolata "Innesti" un nome che comincia con "Innesto:"
	# si legge "Innesto: Innesto: lama".
	for entry in Content.list("seals"):
		var seal: Dictionary = entry
		var nome := String(seal.get("name", ""))
		assert_false(nome.to_lower().begins_with("innesto"),
			"l'innesto %s si chiama '%s'" % [seal.get("id", ""), nome])
