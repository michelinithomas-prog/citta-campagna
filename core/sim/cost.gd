class_name Cost
extends RefCounted
## Curve di costo per shop, upgrade e generatori. Solo funzioni statiche.
##
## La curva si descrive in JSON e si valuta con from_config():
##
##   {"type": "exponential", "base": 10, "growth": 1.15}   costo = 10 * 1.15^livello
##   {"type": "linear",      "base": 10, "step": 5}        costo = 10 + 5*livello
##   {"type": "table",       "values": [5, 12, 30, 80]}    costo per livello, poi ripete l'ultimo
##
## `level` è sempre 0-based: il primo acquisto costa `base`.

const _MAX_LOOP := 100000


static func linear(base: float, step: float, level: int) -> float:
	return base + step * level


static func exponential(base: float, growth: float, level: int) -> float:
	return base * pow(growth, level)


static func table(values: Array, level: int) -> float:
	if values.is_empty():
		return 0.0
	return float(values[clampi(level, 0, values.size() - 1)])


static func from_config(config: Dictionary, level: int) -> float:
	match String(config.get("type", "exponential")):
		"linear":
			return linear(float(config.get("base", 1.0)), float(config.get("step", 1.0)), level)
		"table":
			return table(config.get("values", []), level)
		"flat":
			return float(config.get("base", 1.0))
		_:
			return exponential(float(config.get("base", 1.0)), float(config.get("growth", 1.15)), level)


## Costo totale per comprare `count` livelli partendo da `from_level`.
static func bulk(config: Dictionary, from_level: int, count: int) -> float:
	if count <= 0:
		return 0.0

	if String(config.get("type", "exponential")) == "exponential":
		var base := float(config.get("base", 1.0))
		var growth := float(config.get("growth", 1.15))
		if is_equal_approx(growth, 1.0):
			return base * count
		# Somma geometrica: evita un loop su migliaia di livelli nell'idle.
		return base * pow(growth, from_level) * (pow(growth, count) - 1.0) / (growth - 1.0)

	var total := 0.0
	for i in mini(count, _MAX_LOOP):
		total += from_config(config, from_level + i)
	return total


## Quanti livelli si possono comprare con `budget` partendo da `from_level`.
## È il calcolo dietro ai pulsanti "compra x10 / compra max" degli idle.
static func max_affordable(config: Dictionary, from_level: int, budget: float, limit: int = 1000) -> int:
	if budget <= 0.0:
		return 0

	if String(config.get("type", "exponential")) == "exponential":
		var base := float(config.get("base", 1.0))
		var growth := float(config.get("growth", 1.15))
		var first := base * pow(growth, from_level)
		if first <= 0.0:
			return limit
		if is_equal_approx(growth, 1.0):
			return clampi(int(floorf(budget / first)), 0, limit)
		var ratio := budget * (growth - 1.0) / first + 1.0
		if ratio <= 1.0:
			return 0
		return clampi(int(floorf(log(ratio) / log(growth))), 0, limit)

	var spent := 0.0
	var bought := 0
	while bought < limit:
		var next_cost := from_config(config, from_level + bought)
		if spent + next_cost > budget:
			break
		spent += next_cost
		bought += 1
	return bought
