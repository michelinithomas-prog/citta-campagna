class_name RngStream
extends RefCounted
## Generatore casuale con seed esplicito: stessa partita, stesso risultato.
##
## Non usare mai randi()/randf() globali o Array.shuffle() nella logica di gioco:
## rompono il determinismo e con esso i test. Passa sempre da qui.
##
##   var rng := RngStream.new(12345)
##   rng.chance(0.3)
##   rng.pick(["a", "b", "c"])
##   rng.shuffle(deck)
##
## L'autoload Rng è un'istanza globale di questa classe; nei test si istanzia
## direttamente per avere uno stream isolato.

var _rng := RandomNumberGenerator.new()
var seed_value: int = 0


func _init(initial_seed: int = 0) -> void:
	set_seed(initial_seed)


## Seed 0 = casuale (una run vera). Qualsiasi altro valore = run riproducibile.
func set_seed(value: int) -> void:
	if value == 0:
		_rng.randomize()
		seed_value = int(_rng.seed)
	else:
		seed_value = value
		# Assegnare `seed` reinizializza già lo stato interno.
		# NON toccare `state` qui: azzerarlo degenera il generatore e
		# seed diversi finiscono per produrre la stessa sequenza.
		_rng.seed = value


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func pick(options: Array) -> Variant:
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]


## `weights` deve avere la stessa lunghezza di `options`. Pesi <= 0 sono esclusi.
func pick_weighted(options: Array, weights: Array) -> Variant:
	if options.is_empty() or options.size() != weights.size():
		return null
	var total := 0.0
	for w in weights:
		total += maxf(float(w), 0.0)
	if total <= 0.0:
		return null

	var roll := _rng.randf() * total
	var last_valid: Variant = null
	for i in options.size():
		var weight := maxf(float(weights[i]), 0.0)
		if weight <= 0.0:
			continue  # peso 0 = mai estratto, nemmeno se il tiro cade esattamente lì
		last_valid = options[i]
		roll -= weight
		if roll <= 0.0:
			return options[i]
	return last_valid


## Fisher-Yates sul nostro stream: Array.shuffle() userebbe il RNG globale.
## Mescola in place.
func shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = array[i]
		array[i] = array[j]
		array[j] = tmp


## Estrae `count` elementi distinti senza modificare l'originale.
func sample(options: Array, count: int) -> Array:
	var pool := options.duplicate()
	shuffle(pool)
	return pool.slice(0, mini(count, pool.size()))


## Stato completo, da mettere nel salvataggio per riprendere la run identica.
func to_dict() -> Dictionary:
	return {"seed": seed_value, "state": _rng.state}


func from_dict(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	_rng.seed = seed_value
	_rng.state = int(data.get("state", 0))
