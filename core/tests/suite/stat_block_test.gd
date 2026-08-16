extends TestCase


func test_le_stat_base_si_leggono() -> void:
	var s := StatBlock.new({"hp": 30, "atk": 6})
	assert_eq(s.get_stat("hp"), 30.0)
	assert_eq(s.get_stat("atk"), 6.0)


func test_una_stat_assente_vale_zero() -> void:
	var s := StatBlock.new({"hp": 30})
	assert_eq(s.get_stat("armatura"), 0.0)
	assert_false(s.has("armatura"))


func test_modificatore_flat() -> void:
	var s := StatBlock.new({"atk": 6})
	s.add_mod("atk", StatBlock.FLAT, 4.0)
	assert_eq(s.get_stat("atk"), 10.0)


func test_modificatore_percentuale() -> void:
	var s := StatBlock.new({"atk": 6})
	s.add_mod("atk", StatBlock.PERCENT, 0.5)
	assert_eq(s.get_stat("atk"), 9.0)


func test_ordine_flat_poi_percent_poi_mult() -> void:
	var s := StatBlock.new({"atk": 6})
	s.add_mod("atk", StatBlock.FLAT, 4.0)      # 10
	s.add_mod("atk", StatBlock.PERCENT, 0.5)   # 15
	s.add_mod("atk", StatBlock.MULT, 2.0)      # 30
	assert_eq(s.get_stat("atk"), 30.0)


func test_le_percentuali_si_sommano_fra_loro() -> void:
	var s := StatBlock.new({"atk": 10})
	s.add_mod("atk", StatBlock.PERCENT, 0.5)
	s.add_mod("atk", StatBlock.PERCENT, 0.5)
	assert_eq(s.get_stat("atk"), 20.0, "50% + 50% = +100%, non 2.25x")


func test_remove_source_toglie_solo_i_suoi() -> void:
	var s := StatBlock.new({"atk": 10})
	s.add_mod("atk", StatBlock.FLAT, 5.0, "buff_a")
	s.add_mod("atk", StatBlock.FLAT, 3.0, "buff_b")
	s.remove_source("buff_a")
	assert_eq(s.get_stat("atk"), 13.0)


func test_la_cache_si_invalida_quando_cambia_la_base() -> void:
	var s := StatBlock.new({"hp": 30})
	assert_eq(s.get_stat("hp"), 30.0)
	s.set_base("hp", 50.0)
	assert_eq(s.get_stat("hp"), 50.0)


func test_clone_e_indipendente() -> void:
	var original := StatBlock.new({"atk": 6})
	original.add_mod("atk", StatBlock.FLAT, 4.0, "x")
	var copy := original.clone()
	copy.add_mod("atk", StatBlock.FLAT, 10.0)
	copy.set_base("atk", 100.0)
	assert_eq(original.get_stat("atk"), 10.0, "l'originale non deve cambiare")
	assert_eq(copy.get_stat("atk"), 114.0)


func test_serializzazione_round_trip() -> void:
	var s := StatBlock.new({"hp": 30, "atk": 6})
	s.add_mod("atk", StatBlock.PERCENT, 0.5, "rabbia")
	var restored := StatBlock.from_dict(s.to_dict())
	assert_eq(restored.get_stat("atk"), 9.0)
	restored.remove_source("rabbia")
	assert_eq(restored.get_stat("atk"), 6.0)


func test_get_stat_int_arrotonda() -> void:
	var s := StatBlock.new({"hp": 10})
	s.add_mod("hp", StatBlock.PERCENT, 0.15)
	assert_eq(s.get_stat_int("hp"), 12, "11.5 arrotonda a 12")
