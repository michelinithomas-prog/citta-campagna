extends TestCase

var resolver: EffectResolver
var log: Array[float]


func before_each() -> void:
	resolver = EffectResolver.new(RngStream.new(2024))
	log = []
	resolver.register("danno", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var amount := resolver.value(effect, "amount", ctx, 1.0)
		log.append(amount)
		return amount
	)


func after_each() -> void:
	resolver.clear_handlers()
	resolver = null  # rompe il ciclo lambda ↔ istanza di test


func test_handler_registrato_viene_chiamato() -> void:
	resolver.resolve({"type": "danno", "amount": 6})
	assert_eq(log, [6.0] as Array[float])


func test_tipo_sconosciuto_non_esplode() -> void:
	assert_null(resolver.resolve({"type": "boh"}))
	assert_eq(log.size(), 0)


func test_valore_mancante_usa_il_default() -> void:
	resolver.resolve({"type": "danno"})
	assert_eq(log, [1.0] as Array[float])


func test_all_esegue_in_sequenza() -> void:
	resolver.resolve({"type": "all", "effects": [
		{"type": "danno", "amount": 2},
		{"type": "danno", "amount": 3},
	]})
	assert_eq(log, [2.0, 3.0] as Array[float])


func test_repeat_ripete() -> void:
	resolver.resolve({"type": "repeat", "times": 3, "effect": {"type": "danno", "amount": 4}})
	assert_eq(log, [4.0, 4.0, 4.0] as Array[float])


func test_chance_certa_esegue() -> void:
	resolver.resolve({"type": "chance", "p": 1.0, "effect": {"type": "danno", "amount": 9}})
	assert_eq(log, [9.0] as Array[float])


func test_chance_impossibile_usa_il_ramo_else() -> void:
	resolver.resolve({
		"type": "chance", "p": 0.0,
		"effect": {"type": "danno", "amount": 9},
		"else": {"type": "danno", "amount": 1},
	})
	assert_eq(log, [1.0] as Array[float])


func test_random_sceglie_un_solo_effetto() -> void:
	resolver.resolve({"type": "random", "effects": [
		{"type": "danno", "amount": 1},
		{"type": "danno", "amount": 2},
	]})
	assert_eq(log.size(), 1)


func test_i_meta_effetti_si_annidano() -> void:
	resolver.resolve({"type": "repeat", "times": 2, "effect":
		{"type": "all", "effects": [
			{"type": "danno", "amount": 1},
			{"type": "danno", "amount": 2},
		]}
	})
	assert_eq(log, [1.0, 2.0, 1.0, 2.0] as Array[float])


func test_valore_letto_da_una_stat_del_contesto() -> void:
	var attaccante := StatBlock.new({"atk": 8})
	resolver.resolve({"type": "danno", "amount": {"stat": "atk", "of": "source"}}, {"source": attaccante})
	assert_eq(log, [8.0] as Array[float])


func test_valore_da_stat_con_scala_e_addendo() -> void:
	var attaccante := StatBlock.new({"atk": 8})
	resolver.resolve(
		{"type": "danno", "amount": {"stat": "atk", "of": "source", "scale": 1.5, "add": 2}},
		{"source": attaccante}
	)
	assert_eq(log, [14.0] as Array[float])


func test_stat_di_un_contesto_mancante_usa_il_default() -> void:
	resolver.resolve({"type": "danno", "amount": {"stat": "atk", "of": "source"}})
	assert_eq(log, [1.0] as Array[float], "nessuna source → default, non un crash")


func test_valore_casuale_dentro_i_limiti() -> void:
	for i in 20:
		log.clear()
		resolver.resolve({"type": "danno", "amount": {"random": [1, 6]}})
		assert_gt(log[0], 0.9)
		assert_lt(log[0], 6.1)


func test_lo_stesso_seed_da_lo_stesso_risultato() -> void:
	var run := func(seed_value: int) -> Array:
		var out: Array[float] = []
		var r := EffectResolver.new(RngStream.new(seed_value))
		r.register("danno", func(e: Dictionary, c: Dictionary) -> Variant:
			out.append(r.value(e, "amount", c, 0.0))
			return null
		)
		for i in 10:
			r.resolve({"type": "danno", "amount": {"random": [1, 100]}})
		r.clear_handlers()
		return out
	assert_eq(run.call(77), run.call(77))


func test_has_handler_riconosce_anche_i_meta() -> void:
	assert_true(resolver.has_handler("danno"))
	assert_true(resolver.has_handler("repeat"))
	assert_false(resolver.has_handler("inesistente"))
