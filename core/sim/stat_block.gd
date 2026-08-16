class_name StatBlock
extends RefCounted
## Statistiche con modificatori. Usato da unità, nemici, torri, giocatore.
##
## Formula: (base + FLAT) * (1 + somma dei PERCENT) * (prodotto dei MULT)
## I PERCENT sono frazioni: 0.5 significa +50%.
##
##   var s := StatBlock.new({"hp": 30.0, "atk": 6.0})
##   s.add_mod("atk", StatBlock.PERCENT, 0.5, "rabbia")   # atk = 9
##   s.remove_source("rabbia")                            # atk = 6
##
## I modificatori hanno una `source` (stringa) per poterli togliere in blocco
## quando l'effetto che li aveva messi scade.

enum { FLAT, PERCENT, MULT }

var _base: Dictionary = {}
var _mods: Array[Dictionary] = []
var _cache: Dictionary = {}


func _init(base: Dictionary = {}) -> void:
	for key in base:
		_base[key] = float(base[key])


# --- base ---------------------------------------------------------------

func set_base(stat: String, value: float) -> void:
	_base[stat] = value
	_cache.erase(stat)


func get_base(stat: String) -> float:
	return _base.get(stat, 0.0)


func add_base(stat: String, delta: float) -> void:
	set_base(stat, get_base(stat) + delta)


func has(stat: String) -> bool:
	return _base.has(stat)


func stat_names() -> Array:
	return _base.keys()


# --- modificatori -------------------------------------------------------

func add_mod(stat: String, kind: int, value: float, source: String = "") -> void:
	_mods.append({"stat": stat, "kind": kind, "value": value, "source": source})
	_cache.erase(stat)


## Toglie tutti i modificatori aggiunti con questa source.
func remove_source(source: String) -> void:
	var kept: Array[Dictionary] = []
	for m in _mods:
		if m["source"] == source:
			_cache.erase(m["stat"])
		else:
			kept.append(m)
	_mods = kept


func clear_mods() -> void:
	_mods.clear()
	_cache.clear()


func mods_from(source: String) -> Array[Dictionary]:
	return _mods.filter(func(m: Dictionary) -> bool: return m["source"] == source)


# --- lettura ------------------------------------------------------------

func get_stat(stat: String) -> float:
	if _cache.has(stat):
		return _cache[stat]

	var flat := 0.0
	var percent := 0.0
	var mult := 1.0
	for m in _mods:
		if m["stat"] != stat:
			continue
		match int(m["kind"]):
			FLAT: flat += m["value"]
			PERCENT: percent += m["value"]
			MULT: mult *= m["value"]

	var result: float = (get_base(stat) + flat) * (1.0 + percent) * mult
	_cache[stat] = result
	return result


## Comodo per hp/vite/costi che devono restare interi.
func get_stat_int(stat: String) -> int:
	return int(roundf(get_stat(stat)))


# --- copia e persistenza ------------------------------------------------

## Copia indipendente: modificarla non tocca l'originale.
## Serve ogni volta che istanzi un'unità partendo dai dati del template.
func clone() -> StatBlock:
	var copy := StatBlock.new(_base)
	for m in _mods:
		copy._mods.append(m.duplicate())
	return copy


func to_dict() -> Dictionary:
	return {"base": _base.duplicate(), "mods": _mods.duplicate(true)}


static func from_dict(data: Dictionary) -> StatBlock:
	var block := StatBlock.new(data.get("base", {}))
	for m in data.get("mods", []):
		block._mods.append((m as Dictionary).duplicate())
	return block


func _to_string() -> String:
	var parts: Array[String] = []
	for key in _base:
		parts.append("%s=%s" % [key, get_stat(key)])
	return "StatBlock(%s)" % ", ".join(parts)
