class_name Wallet
extends RefCounted
## Valute multiple con spesa atomica.
##
##   var w := Wallet.new({"gold": 10.0})
##   w.can_afford({"gold": 4})   # true
##   w.spend({"gold": 4})        # true, gold = 6
##
## Una spesa con più valute o passa tutta o non passa: niente stati a metà.
## Il segnale `changed` va inoltrato su Events dal codice di gioco, così la
## classe resta pura e testabile senza autoload.

signal changed(currency: String, amount: float, delta: float)

var _amounts: Dictionary = {}
## Se impostato, la valuta non può superare questi valori. Es. {"energy": 3.0}
var caps: Dictionary = {}


func _init(initial: Dictionary = {}) -> void:
	for key in initial:
		_amounts[key] = float(initial[key])


func get_amount(currency: String) -> float:
	return _amounts.get(currency, 0.0)


func get_amount_int(currency: String) -> int:
	return int(floorf(get_amount(currency)))


func set_amount(currency: String, value: float) -> void:
	var capped: float = value
	if caps.has(currency):
		capped = minf(capped, float(caps[currency]))
	capped = maxf(capped, 0.0)
	var before := get_amount(currency)
	if is_equal_approx(before, capped):
		return
	_amounts[currency] = capped
	changed.emit(currency, capped, capped - before)


func earn(currency: String, value: float) -> void:
	if value <= 0.0:
		return
	set_amount(currency, get_amount(currency) + value)


## Riporta la valuta al suo cap (es. l'energia a inizio turno).
func refill(currency: String) -> void:
	if caps.has(currency):
		set_amount(currency, float(caps[currency]))


## `cost` accetta {"gold": 10, "gems": 1} oppure una singola valuta via cost_one().
func can_afford(cost: Dictionary) -> bool:
	for currency in cost:
		if get_amount(currency) < float(cost[currency]) - 0.0001:
			return false
	return true


func can_afford_one(currency: String, value: float) -> bool:
	return can_afford({currency: value})


## Spende tutto o niente. Restituisce false (senza toccare nulla) se non basta.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for currency in cost:
		set_amount(currency, get_amount(currency) - float(cost[currency]))
	return true


func spend_one(currency: String, value: float) -> bool:
	return spend({currency: value})


func currencies() -> Array:
	return _amounts.keys()


func to_dict() -> Dictionary:
	return _amounts.duplicate()


static func from_dict(data: Dictionary) -> Wallet:
	return Wallet.new(data)


func _to_string() -> String:
	return "Wallet(%s)" % str(_amounts)
