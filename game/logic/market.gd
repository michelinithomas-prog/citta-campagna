class_name Market
extends RefCounted
## La bottega fra un round e l'altro: carte da comprare, sigilli da applicare,
## carte da buttare via.
##
## Il prezzo di una carta non dipende solo dal valore ma anche dalla famiglia, e
## non è un dettaglio estetico: una carta di campagna è lenta, quindi consuma
## meno mazzo, quindi allontana il deck-out. Vale strutturalmente di più di una
## carta di città a parità di numero, e deve costare di più — altrimenti la
## città non ha ragione di esistere.

signal changed

var card_offers: Array[Card] = []
var seal_offers: Array[Dictionary] = []
var relic_offers: Array[Dictionary] = []
var removals := 0

var _rng: RngStream
## Impostato da roll(): serve a scontare i prezzi con le reliquie possedute.
var _run: RunState = null


func _init(rng: RngStream = null) -> void:
	_rng = rng if rng != null else RngStream.new(1)


## Rifà la vetrina. I valori disponibili crescono col round: all'inizio si
## comprano carte piccole, verso la fine arrivano le figure.
func roll(round_number: int = 1, run: RunState = null) -> void:
	_run = run
	card_offers.clear()
	seal_offers.clear()
	relic_offers.clear()

	var high := clampi(3 + round_number, 4, 13)
	# I mazzi non ancora svelati non compaiono in vetrina: nelle prime due sfide
	# si compra solo fra poker e briscola. Chi decide è `RunState`.
	var pesi: Dictionary = run.pesi_svelati() if run != null else {}
	for i in Cfg.get_int("shop.card_offers", 3):
		var card := CardLibrary.random_card(_rng, pesi, [1, high])
		if card != null:
			card_offers.append(card)

	# sample e non pick in un ciclo: pick può restituire due volte lo stesso
	# innesto, e vedere "Borsello" due volte nella stessa vetrina sembra un bug
	# anche quando è solo sfortuna.
	var pool := Content.list("seals")
	if not pool.is_empty():
		var quanti := mini(Cfg.get_int("shop.seal_offers", 2), pool.size())
		for seal in _rng.sample(pool, quanti):
			seal_offers.append(seal)

	# Le reliquie già in tasca non ricompaiono in vetrina: si comprano una volta.
	var relics: Array = Content.filter("relics", func(entry: Dictionary) -> bool:
		# Alcune reliquie si guadagnano solo agli incontri: in vetrina non ci vanno.
		if not bool(entry.get("in_shop", true)):
			return false
		return run == null or not run.has_relic(String(entry.get("id", "")))
	)
	if not relics.is_empty():
		var quante := mini(Cfg.get_int("shop.relic_offers", 2), relics.size())
		for relic in _rng.sample(relics, quante):
			relic_offers.append(relic)

	changed.emit()


# --- prezzi --------------------------------------------------------------

func card_price(card: Card) -> int:
	if card == null:
		return 0
	var cfg: Dictionary = Cfg.get_value("shop.card_cost", {})
	var price := (float(cfg.get("base", 2.0)) + card.value() * float(cfg.get("per_value", 0.35)))
	# Il moltiplicatore di famiglia sta in families.json, una riga per mazzo:
	# è la stessa riga che ne porta nome, colore e peso, e con quattro mazzi
	# tenerlo altrove significa cercarlo in due posti.
	price *= float(card.family_entry().get("price_multiplier", 1.0))
	return _scontato(price)


func seal_price(seal: Dictionary) -> int:
	return _scontato(float(seal.get("cost", 4)))


func relic_price(relic: Dictionary) -> int:
	return _scontato(float(relic.get("cost", 10)))


## Il prezzo che il giocatore vede e paga, sconti compresi. Passa da qui tutto
## quello che si compra: se lo sconto valesse solo su una cosa si noterebbe.
##
## Lo sconto arrotonda per difetto, il prezzo pieno al più vicino. Non è un
## capriccio: con prezzi da tre o quattro monete, un venti per cento arrotondato
## al più vicino sparisce (3 × 0,8 = 2,4 → 3) e la reliquia dello sconto non fa
## niente di visibile. Arrotondando a favore di chi compra, si vede sempre.
func _scontato(price: float) -> int:
	var factor := _run.price_multiplier() if _run != null else 1.0
	if factor < 1.0:
		return maxi(int(floorf(price * factor)), 1)
	return maxi(int(roundf(price * factor)), 1)


## Ogni carta tolta costa più della precedente: sfoltire il mazzo è potente e
## non deve diventare la mossa ovvia da ripetere ogni round.
func remove_price() -> int:
	return maxi(int(roundf(Cost.from_config(Cfg.get_value("shop.remove_cost", {}), removals))), 1)


func reroll_price() -> int:
	return maxi(Cfg.get_int("shop.reroll_cost", 2), 0)


# --- acquisti ------------------------------------------------------------

func buy_card(index: int, run: RunState) -> Card:
	if index < 0 or index >= card_offers.size():
		return null
	var card: Card = card_offers[index]
	if not run.spend(card_price(card)):
		return null

	card_offers.remove_at(index)
	run.add_card(card)
	changed.emit()
	return card


## Applica un sigillo a una carta del mazzo. Fallisce senza spendere niente se
## la carta è già piena.
func buy_seal(index: int, card: Card, run: RunState) -> bool:
	if index < 0 or index >= seal_offers.size() or card == null:
		return false
	if card.seals.size() >= Card.MAX_SEALS:
		return false

	var seal: Dictionary = seal_offers[index]
	if not run.spend(seal_price(seal)):
		return false
	if not card.add_seal(seal):
		# Non dovrebbe succedere, ma se succede l'oro torna indietro.
		run.earn(seal_price(seal))
		return false

	seal_offers.remove_at(index)
	changed.emit()
	return true


func buy_relic(index: int, run: RunState) -> Dictionary:
	if index < 0 or index >= relic_offers.size():
		return {}
	var relic: Dictionary = relic_offers[index]
	var price := relic_price(relic)
	if not run.spend(price):
		return {}
	if not run.add_relic(relic, _rng):
		run.earn(price)
		return {}

	relic_offers.remove_at(index)
	changed.emit()
	return relic


func remove_card(card: Card, run: RunState) -> bool:
	if card == null or not run.can_remove():
		return false
	var price := remove_price()
	if not run.spend(price):
		return false
	if not run.remove_card(card):
		run.earn(price)
		return false

	removals += 1
	changed.emit()
	return true


func reroll(run: RunState, round_number: int) -> bool:
	if not run.spend(reroll_price()):
		return false
	roll(round_number, run)
	return true
