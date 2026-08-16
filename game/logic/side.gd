class_name Side
extends RefCounted
## Uno dei due schieramenti: vita, scudo, pila e i cinque slot della plancia.
##
## Non sa niente dell'avversario e non decide niente: scandisce i cooldown, dice
## quando una carta è pronta e si riempie i buchi. Chi risolve gli effetti è il
## Duel, che vede tutti e due i lati.
##
## Le due sconfitte vivono qui: gli HP che finiscono e la pila che finisce.

signal card_ready(slot: int, card: Card)
signal slot_filled(slot: int, card: Card)
signal slot_changed(slot: int)
signal hp_changed(current: int, maximum: int)
signal shield_changed(amount: int)
signal status_changed
signal defeated(reason: String)

const SHIELD := "shield"
const GOLD := "gold"

const REASON_HP := "hp"
const REASON_DECKOUT := "deckout"

var display_name := ""
var is_player := false

var max_hp := 50
var hp := 50
var purse: Wallet

var pile: CardPile
var board: Array[Card] = []
var board_size := 5

var is_out := false
var defeat_reason := ""

# --- stati alterati -------------------------------------------------------
#
# Vivono sul lato, non sulla carta: sono ferite del personaggio, e tenerli fuori
# da Card significa che clone() non può portarseli dietro nel mazzo della run.
# Nessuno dei due passa dallo scudo: lo scudo para i colpi, non l'avvelenamento.

## Quanto veleno e sanguinamento questo lato si scrolla di dosso a ogni
## applicazione. Chi ha un fegato allenato ne prende meno.
var status_resist := 0

## Danno al secondo che si consuma: infligge il suo numero, poi cala di uno.
var bleed := 0
## Danno al secondo che **non** cala. Dura fino a fine battaglia o a un `cleanse`.
var poison := 0

# --- modificatori temporanei ----------------------------------------------

## Bonus validi fino a fine battaglia (il Re): li prende ogni carta che entra.
var match_mods: Array[Dictionary] = []
## Un buff per slot, parallelo a `board`. Appartiene al posto, non alla carta:
## la Donna potenzia lo slot, e ne gode chiunque ci passi. Il nuovo cancella il
## vecchio — se ne può tenere uno solo, o non si legge più cosa sta succedendo.
var slot_buffs: Array[Dictionary] = []
## Secondi di paralisi residui, per slot. A differenza del buff appartiene alla
## creatura: se la carta se ne va, la paralisi se ne va con lei.
var paralysis: Array[float] = []

## Come si costruisce una carta nata a metà battaglia (un seme d'erba, un
## gaiofanamon dell'Antigh). Di default è la carta nuda dei JSON; `play.gd` ci
## infila la versione con i passivi della run già addosso, perché il Duel non
## conosce la RunState e non deve conoscerla.
var card_maker: Callable = func(card_id: String) -> Card: return CardLibrary.build(card_id)

# --- la catena di One ------------------------------------------------------
#
# Ogni volta che una carta se ne va e quella che prende il suo posto le somiglia
# — stesso colore o stesso numero — la catena si allunga, e da lì in poi *tutte*
# le carte del lato colpiscono, curano e riparano di più. Non cala da sola: solo
# la carta Blocco la spegne, ed è per questo che il Pesca Quattro, che la
# allunga di colpo, si porta dietro un Blocco da mettere nel mazzo.

signal combo_changed(value: int)

var combo := 0

## La carta appena uscita da ogni slot: serve a sapere con chi confrontare
## quella che arriva. Parallelo a `board`.
var last_left: Array[Card] = []


func _init(name_text: String = "", cards: Array = [], rng: RngStream = null, config: Dictionary = {}) -> void:
	display_name = name_text
	max_hp = maxi(int(config.get("hp", 50)), 1)
	hp = max_hp
	board_size = maxi(int(config.get("board_size", 5)), 1)
	is_player = bool(config.get("is_player", false))

	status_resist = maxi(int(config.get("status_resist", 0)), 0)
	combo = maxi(int(config.get("combo", 0)), 0)

	purse = Wallet.new({SHIELD: float(config.get("shield", 0)), GOLD: 0.0})
	pile = CardPile.new(cards, rng)

	board.resize(board_size)
	slot_buffs.resize(board_size)
	paralysis.resize(board_size)
	last_left.resize(board_size)
	for slot in board_size:
		slot_buffs[slot] = {}
		paralysis[slot] = 0.0


## Riempie la plancia per la prima volta. Se il mazzo non basta nemmeno a
## coprire gli slot, la battaglia è già persa: meglio saperlo subito.
func begin() -> void:
	refill()


## Rimette una carta in ogni slot vuoto. È qui che scatta il deck-out.
func refill() -> void:
	if is_out:
		return
	for slot in board_size:
		if board[slot] != null:
			continue
		var card := pile.draw()
		if card == null:
			_lose(REASON_DECKOUT)
			return
		card.reset_for_battle()
		board[slot] = card
		_apply_slot_state(slot, true)
		slot_filled.emit(slot, card)


## Fa scorrere il tempo su tutta la plancia e restituisce gli slot pronti a
## partire, in ordine. Non li svuota: risolvere è compito del Duel.
func advance_cooldowns(step: float) -> Array[int]:
	var ready: Array[int] = []
	if is_out:
		return ready
	for slot in board_size:
		var card := board[slot]
		if card == null:
			continue
		# Una carta paralizzata consuma la paralisi invece del cooldown: il tempo
		# per lei non passa. Sta qui e non nel tick da un secondo perché deve
		# scorrere fluida come i cooldown, con la stessa tolleranza.
		if paralysis[slot] > SimClock.EPSILON:
			paralysis[slot] = maxf(paralysis[slot] - step, 0.0)
			continue
		card.cooldown -= step
		# Stessa tolleranza di SimClock: sommando passi da 0.05 resta un residuo
		# di 1e-17 e senza epsilon ogni tanto si perde un'attivazione.
		if card.cooldown <= SimClock.EPSILON:
			ready.append(slot)
	return ready


## Toglie la carta dallo slot (senza rimpiazzarla: ci pensa refill()).
##
## Il buff dello slot **resta**: è del posto, e ne godrà chi arriva dopo. Se ne
## vanno invece la paralisi — era della creatura — e i modificatori temporanei
## che la carta aveva addosso: una carta fuori dalla plancia non deve portarsi
## dietro il potenziamento di un posto che non occupa più, o se la ritroverebbe
## addosso chi la recupera dagli scarti.
func take_from(slot: int) -> Card:
	if slot < 0 or slot >= board.size():
		return null
	var card := board[slot]
	board[slot] = null
	paralysis[slot] = 0.0
	last_left[slot] = card
	if card != null:
		card.stats.remove_source(Card.MOD_SLOT)
		card.stats.remove_source(Card.MOD_MATCH)
	return card


## Mette una carta in uno slot senza passare dalla pila. Sono due i modi in cui
## succede — rubarla all'avversario ed evolverla — e tutti e due lasciano lo slot
## sempre pieno: senza `slot_filled` la schermata continuerebbe a mostrare la
## carta di prima per il resto della battaglia.
func put_in(slot: int, card: Card, fresh: bool = true) -> bool:
	if is_out or card == null or slot < 0 or slot >= board.size():
		return false
	board[slot] = card
	paralysis[slot] = 0.0
	if fresh:
		card.reset_for_battle()
	_apply_slot_state(slot, true)
	slot_filled.emit(slot, card)
	return true


func discard(card: Card) -> void:
	pile.discard(card)


func recycle(card: Card) -> void:
	pile.recycle(card)


# --- vita e scudo --------------------------------------------------------

## Il danno passa prima dallo scudo. Restituisce quanto è arrivato agli HP —
## ed è quel numero, non l'altro, che il lifesteal converte in cura: rubare vita
## a uno scudo pieno non cura niente, ed è la limitazione giusta.
##
## Con `pierce` lo scudo non c'entra: è il colpo delle Spade, che passa.
func take_damage(amount: int, pierce: bool = false) -> int:
	if amount <= 0 or is_out:
		return 0
	if pierce:
		return _damage_hp(amount)

	var absorbed := mini(amount, shield())
	if absorbed > 0:
		purse.spend_one(SHIELD, float(absorbed))
		shield_changed.emit(shield())

	var to_hp := amount - absorbed
	if to_hp <= 0:
		return 0
	return _damage_hp(to_hp)


## Direttamente agli HP, senza chiedere permesso allo scudo.
func _damage_hp(amount: int) -> int:
	if amount <= 0 or is_out:
		return 0
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_lose(REASON_HP)
	return amount


# --- stati alterati ------------------------------------------------------

## Anche il sanguinamento ha un tetto, e per un motivo meno ovvio del veleno:
## cala di uno al secondo, ma cinque carte che ne applicano uno ciascuna ogni
## due secondi lo fanno salire più in fretta di quanto scenda. Senza soffitto
## un mazzo di soli Due non perde mai, e non perché sia una bella strategia.
func apply_bleed(amount: int) -> void:
	amount -= status_resist
	if amount <= 0 or is_out:
		return
	bleed = mini(bleed + amount, maxi(Cfg.get_int("battle.bleed_cap", 6), 1))
	status_changed.emit()


## Il veleno ha un tetto, e non è un dettaglio: un danno al secondo che non cala
## vale, in una battaglia da venti secondi, dieci volte il suo numero. Senza
## soffitto due carte da veleno chiudono la partita da sole.
func apply_poison(amount: int) -> void:
	amount -= status_resist
	if amount <= 0 or is_out:
		return
	poison = mini(poison + amount, maxi(Cfg.get_int("battle.poison_cap", 5), 1))
	status_changed.emit()


## Toglie tutto quello che rode. È la risposta ai danni nel tempo — non lo scudo,
## che contro veleno e sanguinamento non serve a niente.
func cleanse() -> int:
	var tolti := bleed + poison
	if tolti <= 0:
		return 0
	bleed = 0
	poison = 0
	status_changed.emit()
	return tolti


## Un secondo di sanguinamento: infligge il suo numero, poi cala di uno. Colpo
## forte adesso, e si spegne da solo.
func tick_bleed() -> int:
	if is_out or bleed <= 0:
		return 0
	var danno := bleed
	bleed -= 1
	status_changed.emit()
	return _damage_hp(danno)


## Un morso di veleno. Scatta più di rado del sanguinamento — ogni
## `battle.poison_every` secondi — e questo non è un dettaglio di ritmo: è il
## prezzo. Un danno *ogni secondo* che non finisce mai vale, in una battaglia
## normale, quasi dieci volte il suo numero, cioè più di quanto una carta possa
## permettersi a qualunque costo. Diradandolo il veleno resta quello che è
## — fisso, e non se ne va finché non lo lavi — a un prezzo che si può pagare.
func tick_poison() -> int:
	if is_out or poison <= 0:
		return 0
	status_changed.emit()
	return _damage_hp(poison)


# --- buff di slot e di partita -------------------------------------------

func slot_buff(slot: int) -> Dictionary:
	return slot_buffs[slot] if slot >= 0 and slot < slot_buffs.size() else {}


## Uno slot tiene un buff solo: il nuovo cancella il vecchio, senza sommarsi.
func set_slot_buff(slot: int, buff: Dictionary) -> void:
	if slot < 0 or slot >= slot_buffs.size():
		return
	slot_buffs[slot] = buff.duplicate(true)
	_apply_slot_state(slot)
	slot_changed.emit(slot)


## Un bonus che vale fino alla fine della battaglia, per tutte le carte: quelle
## già in campo e quelle che arriveranno.
func add_match_mod(stat: String, kind: int, value: float) -> void:
	match_mods.append({"stat": stat, "kind": kind, "value": value})
	for slot in board_size:
		if board[slot] != null:
			_apply_slot_state(slot)


## Rimette in ordine i modificatori temporanei della carta che sta in quello
## slot. Toglie prima e riapplica dopo, così chiamarla due volte non raddoppia
## niente — ed è l'unico motivo per cui il buff di slot e quello di partita
## hanno due `source` diverse: `remove_source` lavora in blocco.
func _apply_slot_state(slot: int, entering: bool = false) -> void:
	var card := board[slot]
	if card == null:
		return

	card.stats.remove_source(Card.MOD_SLOT)
	card.stats.remove_source(Card.MOD_MATCH)
	for mod in match_mods:
		card.stats.add_mod(String(mod["stat"]), int(mod["kind"]), float(mod["value"]), Card.MOD_MATCH)

	var buff: Dictionary = slot_buffs[slot]
	if buff.has("value_add"):
		card.stats.add_mod("value", StatBlock.FLAT, float(buff["value_add"]), Card.MOD_SLOT)
	if buff.has("value_mult"):
		card.stats.add_mod("value", StatBlock.MULT, float(buff["value_mult"]), Card.MOD_SLOT)
	# L'attesa si accorcia solo quando la carta entra: applicarla anche a ogni
	# ritocco del buff permetterebbe di far scattare una carta ritoccandola.
	if entering and buff.has("cooldown_mult"):
		card.cooldown = maxf(card.cooldown * float(buff["cooldown_mult"]), SimClock.EPSILON * 2.0)


## Ferma il tempo su uno slot, o su tutta la plancia con -1. Le paralisi non si
## sommano: vale la più lunga, o due carte elettriche bloccherebbero la partita.
func paralyze(seconds: float, slot: int = -1) -> void:
	if seconds <= 0.0 or is_out:
		return
	if slot >= 0:
		if slot < paralysis.size():
			paralysis[slot] = maxf(paralysis[slot], seconds)
		return
	for i in board_size:
		if board[i] != null:
			paralysis[i] = maxf(paralysis[i], seconds)


func heal(amount: int) -> void:
	if amount <= 0 or is_out:
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func add_shield(amount: int) -> void:
	if amount <= 0 or is_out:
		return
	purse.earn(SHIELD, float(amount))
	shield_changed.emit(shield())


func shield() -> int:
	return purse.get_amount_int(SHIELD)


func earn_gold(amount: int) -> void:
	if amount <= 0:
		return
	purse.earn(GOLD, float(amount))


## Toglie oro, ma solo quello che c'è: le carte delle Picche costano, non
## indebitano. Restituisce quanto è stato tolto davvero.
# --- la catena di One ----------------------------------------------------

## Quanto valgono di più, adesso, colpi cure e scudi di questo lato.
func combo_multiplier() -> float:
	return 1.0 + combo * maxf(Cfg.get_float("battle.combo_step", 0.10), 0.0)


func add_combo(amount: int) -> void:
	if amount <= 0 or is_out:
		return
	combo = mini(combo + amount, maxi(Cfg.get_int("battle.combo_cap", 10), 1))
	combo_changed.emit(combo)


## La spegne di netto. Lo fa solo la carta Blocco, che nel mazzo ci finisce in
## un modo solo: se l'hai messa tu giocando un Pesca Quattro.
func reset_combo() -> void:
	if combo == 0:
		return
	combo = 0
	combo_changed.emit(combo)


func spend_gold(amount: int) -> int:
	if amount <= 0:
		return 0
	var tolti := mini(amount, gold())
	if tolti > 0:
		purse.spend_one(GOLD, float(tolti))
	return tolti


func gold() -> int:
	return purse.get_amount_int(GOLD)


func hp_ratio() -> float:
	return float(hp) / float(maxi(max_hp, 1))


# --- lettura della plancia -----------------------------------------------

func cards_on_board() -> Array[Card]:
	var out: Array[Card] = []
	for card in board:
		if card != null:
			out.append(card)
	return out


## Lo slot con la carta più vicina a partire. È il bersaglio di "burn": bruciare
## quella che stava per scattare è il colpo che fa male davvero.
func most_imminent_slot() -> int:
	var best := -1
	var best_time := INF
	for slot in board_size:
		var card := board[slot]
		if card != null and card.cooldown < best_time:
			best_time = card.cooldown
			best = slot
	return best


func _lose(reason: String) -> void:
	if is_out:
		return
	is_out = true
	defeat_reason = reason
	defeated.emit(reason)
