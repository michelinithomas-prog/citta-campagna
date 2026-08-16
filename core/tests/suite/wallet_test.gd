extends TestCase

var wallet: Wallet


func before_each() -> void:
	wallet = Wallet.new({"gold": 10.0, "gems": 2.0})


func after_each() -> void:
	wallet = null  # rompe il ciclo lambda ↔ istanza di test


func test_lettura_iniziale() -> void:
	assert_eq(wallet.get_amount("gold"), 10.0)
	assert_eq(wallet.get_amount("inesistente"), 0.0)


func test_earn_somma() -> void:
	wallet.earn("gold", 5.0)
	assert_eq(wallet.get_amount("gold"), 15.0)


func test_earn_ignora_valori_non_positivi() -> void:
	wallet.earn("gold", -5.0)
	assert_eq(wallet.get_amount("gold"), 10.0)


func test_spend_riesce_e_scala() -> void:
	assert_true(wallet.spend({"gold": 4.0}))
	assert_eq(wallet.get_amount("gold"), 6.0)


func test_spend_fallisce_senza_fondi() -> void:
	assert_false(wallet.spend({"gold": 999.0}))
	assert_eq(wallet.get_amount("gold"), 10.0, "un acquisto fallito non tocca il saldo")


func test_spend_multivaluta_e_atomico() -> void:
	assert_false(wallet.spend({"gold": 5.0, "gems": 99.0}))
	assert_eq(wallet.get_amount("gold"), 10.0, "l'oro non va speso se le gemme non bastano")
	assert_eq(wallet.get_amount("gems"), 2.0)


func test_spesa_esatta_del_saldo() -> void:
	assert_true(wallet.spend({"gold": 10.0}))
	assert_eq(wallet.get_amount("gold"), 0.0)


func test_il_saldo_non_va_sotto_zero() -> void:
	wallet.set_amount("gold", -50.0)
	assert_eq(wallet.get_amount("gold"), 0.0)


func test_il_cap_limita_i_guadagni() -> void:
	wallet.caps["energy"] = 3.0
	wallet.earn("energy", 10.0)
	assert_eq(wallet.get_amount("energy"), 3.0)


func test_refill_riporta_al_cap() -> void:
	wallet.caps["energy"] = 3.0
	wallet.set_amount("energy", 0.0)
	wallet.refill("energy")
	assert_eq(wallet.get_amount("energy"), 3.0)


func test_il_segnale_changed_riporta_il_delta() -> void:
	var seen := []
	wallet.changed.connect(func(c: String, a: float, d: float) -> void: seen.append([c, a, d]))
	wallet.earn("gold", 5.0)
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], "gold")
	assert_eq(seen[0][1], 15.0)
	assert_eq(seen[0][2], 5.0)


func test_nessun_segnale_se_il_valore_non_cambia() -> void:
	var count := [0]
	wallet.changed.connect(func(_c: String, _a: float, _d: float) -> void: count[0] += 1)
	wallet.set_amount("gold", 10.0)
	assert_eq(count[0], 0)


func test_serializzazione_round_trip() -> void:
	var restored := Wallet.from_dict(wallet.to_dict())
	assert_eq(restored.get_amount("gold"), 10.0)
	assert_eq(restored.get_amount("gems"), 2.0)
