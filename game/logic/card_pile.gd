class_name CardPile
extends RefCounted
## La pila di un lato durante una battaglia. È la clessidra del gioco.
##
## Differenza dal solito mazzo da deckbuilder: **gli scarti non tornano mai
## dentro**. Quando la pila è finita è finita, e chi deve rimpiazzare una carta
## senza averne più perde la battaglia. Per questo `draw()` restituisce `null`
## invece di rimescolare: quel null è una condizione di sconfitta, non un caso
## limite da nascondere.
##
## Le carte vengono clonate all'ingresso: quello che succede qui non tocca il
## mazzo della run.

signal changed

var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []

var _rng: RngStream


func _init(cards: Array = [], rng: RngStream = null) -> void:
	_rng = rng if rng != null else RngStream.new(1)
	for card in cards:
		if card is Card:
			draw_pile.append((card as Card).clone())
	_rng.shuffle(draw_pile)


## La prossima carta, o null se la pila è vuota. Non rimescola: è voluto.
func draw() -> Card:
	if draw_pile.is_empty():
		return null
	var card: Card = draw_pile.pop_back()
	changed.emit()
	return card


func discard(card: Card) -> void:
	if card == null:
		return
	discard_pile.append(card)
	changed.emit()


## Rimette una carta in fondo alla pila: sarà l'ultima a uscire. È quello che fa
## il sigillo "Eco", ed è il gesto con cui si allontana il deck-out.
func recycle(card: Card) -> void:
	if card == null:
		return
	draw_pile.push_front(card)
	changed.emit()


## Mette una carta in **cima**: sarà la prossima a uscire. Serve a chi ne crea a
## metà battaglia — un seme d'erba deve scendere in campo, non mettersi in coda
## dietro venti carte e non arrivarci mai.
func insert_top(card: Card) -> void:
	if card == null:
		return
	draw_pile.append(card)
	changed.emit()


## Infila una carta in un punto qualsiasi della pila. È il modo di mettere in
## mazzo qualcosa che deve uscire **prima o poi**, non adesso: un Blocco messo
## in cima verrebbe ripescato dallo stesso slot che l'ha appena generato, e la
## catena che il Pesca Quattro ha appena costruito si spegnerebbe da sola un
## istante dopo.
func insert_random(card: Card, rng: RngStream = null) -> void:
	if card == null:
		return
	var stream := rng if rng != null else _rng
	draw_pile.insert(stream.randi_range(0, draw_pile.size()), card)
	changed.emit()


## Scarta N carte dalla cima senza farle risolvere: è il modo di attaccare il
## mazzo dell'avversario da lontano. **Non fa perdere nessuno adesso** — il
## deck-out scatta quando toccherà rimpiazzare una carta e non ci sarà più
## niente da pescare. È un colpo differito, e il testo della carta deve dirlo.
func mill(count: int) -> int:
	var tolte := 0
	for i in maxi(count, 0):
		var card := draw()
		if card == null:
			break
		discard(card)
		tolte += 1
	return tolte


## Ripesca N carte a caso dagli scarti e le rimette in fondo alla pila: si
## rigiocheranno, ma per ultime. Gli scarti non tornano *mai* in blocco — quella
## è la regola da cui nasce la sconfitta per esaurimento — ma una carta alla
## volta sì, ed è l'unica ragione per cui vale la pena evolvere qualcosa che poi
## finisce sotto la pila degli scarti.
func recover(rng: RngStream = null, count: int = 1) -> Array[Card]:
	var out: Array[Card] = []
	var stream := rng if rng != null else _rng
	for i in maxi(count, 0):
		if discard_pile.is_empty():
			break
		var index := stream.randi_range(0, discard_pile.size() - 1)
		var card: Card = discard_pile[index]
		discard_pile.remove_at(index)
		draw_pile.push_front(card)
		out.append(card)
	if not out.is_empty():
		changed.emit()
	return out


func is_empty() -> bool:
	return draw_pile.is_empty()


func remaining() -> int:
	return draw_pile.size()


func discarded() -> int:
	return discard_pile.size()


## Cerca per id nella pila da pescare. Nei test si cerca sempre così: la pila è
## mescolata, la posizione non significa niente.
func find(card_id: String) -> int:
	for i in draw_pile.size():
		if draw_pile[i].id == card_id:
			return i
	return -1
