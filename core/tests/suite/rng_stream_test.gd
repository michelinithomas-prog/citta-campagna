extends TestCase


func test_stesso_seed_stessa_sequenza() -> void:
	var a := RngStream.new(42)
	var b := RngStream.new(42)
	for i in 20:
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000))


func test_seed_diversi_sequenze_diverse() -> void:
	var a := RngStream.new(1)
	var b := RngStream.new(2)
	var diverse := false
	for i in 20:
		if a.randi_range(0, 1000) != b.randi_range(0, 1000):
			diverse = true
	assert_true(diverse)


func test_chance_agli_estremi() -> void:
	var rng := RngStream.new(7)
	for i in 20:
		assert_true(rng.chance(1.0))
		assert_false(rng.chance(0.0))


func test_pick_resta_dentro_le_opzioni() -> void:
	var rng := RngStream.new(3)
	var options := ["a", "b", "c"]
	for i in 20:
		assert_has(options, rng.pick(options))


func test_pick_su_array_vuoto_da_null() -> void:
	assert_null(RngStream.new(1).pick([]))


func test_pick_weighted_ignora_i_pesi_a_zero() -> void:
	var rng := RngStream.new(5)
	for i in 30:
		assert_eq(rng.pick_weighted(["mai", "sempre"], [0.0, 1.0]), "sempre")


func test_pick_weighted_rispetta_le_proporzioni() -> void:
	var rng := RngStream.new(11)
	var raro := 0
	for i in 2000:
		if rng.pick_weighted(["raro", "comune"], [1.0, 9.0]) == "raro":
			raro += 1
	assert_gt(raro, 120, "atteso ~200 su 2000")
	assert_lt(raro, 300)


func test_shuffle_e_deterministico_e_conserva_gli_elementi() -> void:
	var a := [1, 2, 3, 4, 5, 6, 7, 8]
	var b := a.duplicate()
	RngStream.new(99).shuffle(a)
	RngStream.new(99).shuffle(b)
	assert_eq(a, b)
	a.sort()
	assert_eq(a, [1, 2, 3, 4, 5, 6, 7, 8])


func test_shuffle_cambia_davvero_l_ordine() -> void:
	var deck := range(30)
	var original := deck.duplicate()
	RngStream.new(4).shuffle(deck)
	assert_ne(deck, original)


func test_sample_estrae_elementi_distinti_senza_toccare_l_originale() -> void:
	var pool := [1, 2, 3, 4, 5]
	var picked := RngStream.new(8).sample(pool, 3)
	assert_eq(picked.size(), 3)
	assert_eq(pool.size(), 5)
	var seen := {}
	for p in picked:
		assert_false(seen.has(p), "nessun duplicato")
		seen[p] = true


func test_sample_non_supera_la_dimensione_del_pool() -> void:
	assert_eq(RngStream.new(1).sample([1, 2], 10).size(), 2)


func test_lo_stato_si_salva_e_si_riprende() -> void:
	var rng := RngStream.new(123)
	for i in 5:
		rng.randf()
	var snapshot := rng.to_dict()
	var expected := rng.randi_range(0, 99999)

	var restored := RngStream.new(1)
	restored.from_dict(snapshot)
	assert_eq(restored.randi_range(0, 99999), expected)
