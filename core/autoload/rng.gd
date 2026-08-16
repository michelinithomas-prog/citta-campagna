extends Node
## Istanza globale di RngStream. Usa questa e mai randi()/randf() globali:
## il seed rende ogni partita riproducibile, e i test deterministici.
##
##   Rng.new_run()            # seed casuale, stampato in console
##   Rng.new_run(12345)       # rigioca esattamente la stessa partita
##   Rng.chance(0.25)
##
## Il seed della run corrente è in Rng.seed_value: mostralo nella schermata di
## game over, così un bug segnalato in jam si riproduce.

var stream := RngStream.new(1)

var seed_value: int:
	get:
		return stream.seed_value


## Da chiamare all'inizio di ogni partita. Seed 0 = casuale.
func new_run(run_seed: int = 0) -> int:
	stream.set_seed(run_seed)
	return stream.seed_value


func randi_range(from: int, to: int) -> int:
	return stream.randi_range(from, to)


func randf() -> float:
	return stream.randf()


func randf_range(from: float, to: float) -> float:
	return stream.randf_range(from, to)


func chance(probability: float) -> bool:
	return stream.chance(probability)


func pick(options: Array) -> Variant:
	return stream.pick(options)


func pick_weighted(options: Array, weights: Array) -> Variant:
	return stream.pick_weighted(options, weights)


func shuffle(array: Array) -> void:
	stream.shuffle(array)


func sample(options: Array, count: int) -> Array:
	return stream.sample(options, count)
