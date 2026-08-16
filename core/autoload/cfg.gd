extends Node
## Numeri di bilanciamento, separati dal codice.
##
## Legge res://game/data/tuning.json e lo espone con path a punti:
##
##   {"player": {"hp": 30}, "shop": {"reroll_cost": 1}}
##   Cfg.get_value("player.hp", 20)   ->  30
##
## Premendo F5 in gioco il file viene riletto senza riavviare: si cambia un
## numero, si salva, si vede subito l'effetto. È il modo più veloce di bilanciare
## durante una jam.

const TUNING_PATH := "res://game/data/tuning.json"

var _values: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> bool:
	_values = _read_json(TUNING_PATH)
	return not _values.is_empty()


## `path` è a punti: "shop.reroll_cost". Il default torna anche se il tipo non
## corrisponde, così un JSON scritto male non fa crashare il gioco.
func get_value(path: String, default_value: Variant = null) -> Variant:
	var node: Variant = _values
	for key in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(key):
			return default_value
		node = (node as Dictionary)[key]
	return node


func get_float(path: String, default_value: float = 0.0) -> float:
	var v: Variant = get_value(path, default_value)
	return float(v) if (v is float or v is int) else default_value


func get_int(path: String, default_value: int = 0) -> int:
	var v: Variant = get_value(path, default_value)
	return int(v) if (v is float or v is int) else default_value


func get_bool(path: String, default_value: bool = false) -> bool:
	var v: Variant = get_value(path, default_value)
	return bool(v) if v is bool else default_value


func has(path: String) -> bool:
	return get_value(path) != null


func all() -> Dictionary:
	return _values


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cfg: impossibile aprire %s" % path)
		return {}

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("Cfg: %s non è JSON valido — riga %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		push_error("Cfg: %s deve contenere un oggetto JSON" % path)
		return {}
	return json.data
