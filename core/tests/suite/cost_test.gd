extends TestCase

const EXP := {"type": "exponential", "base": 10.0, "growth": 2.0}
const LIN := {"type": "linear", "base": 10.0, "step": 5.0}


func test_il_primo_acquisto_costa_base() -> void:
	assert_eq(Cost.from_config(EXP, 0), 10.0)
	assert_eq(Cost.from_config(LIN, 0), 10.0)


func test_curva_esponenziale() -> void:
	assert_eq(Cost.from_config(EXP, 3), 80.0)


func test_curva_lineare() -> void:
	assert_eq(Cost.from_config(LIN, 3), 25.0)


func test_curva_a_tabella_ripete_l_ultimo_valore() -> void:
	var cfg := {"type": "table", "values": [5, 12, 30]}
	assert_eq(Cost.from_config(cfg, 1), 12.0)
	assert_eq(Cost.from_config(cfg, 99), 30.0)


func test_tipo_sconosciuto_ricade_su_esponenziale() -> void:
	assert_eq(Cost.from_config({"base": 10.0, "growth": 2.0}, 1), 20.0)


func test_bulk_somma_i_livelli() -> void:
	assert_almost(Cost.bulk(EXP, 0, 3), 70.0, 0.001, "10 + 20 + 40")
	assert_almost(Cost.bulk(LIN, 0, 3), 45.0, 0.001, "10 + 15 + 20")


func test_bulk_parte_dal_livello_giusto() -> void:
	assert_almost(Cost.bulk(EXP, 2, 2), 120.0, 0.001, "40 + 80")


func test_bulk_di_zero_livelli_e_gratis() -> void:
	assert_eq(Cost.bulk(EXP, 5, 0), 0.0)


func test_bulk_regge_una_crescita_pari_a_uno() -> void:
	assert_almost(Cost.bulk({"type": "exponential", "base": 7.0, "growth": 1.0}, 0, 4), 28.0)


func test_max_affordable_esponenziale() -> void:
	assert_eq(Cost.max_affordable(EXP, 0, 70.0), 3)
	assert_eq(Cost.max_affordable(EXP, 0, 69.0), 2)
	assert_eq(Cost.max_affordable(EXP, 0, 9.0), 0)


func test_max_affordable_lineare() -> void:
	assert_eq(Cost.max_affordable(LIN, 0, 45.0), 3)
	assert_eq(Cost.max_affordable(LIN, 0, 44.0), 2)


func test_max_affordable_e_coerente_con_bulk() -> void:
	var budget := 5000.0
	var n := Cost.max_affordable(EXP, 4, budget)
	assert_lt(Cost.bulk(EXP, 4, n), budget + 0.001, "n livelli devono starci")
	assert_gt(Cost.bulk(EXP, 4, n + 1), budget, "n+1 livelli non devono starci")


func test_budget_nullo_non_compra_niente() -> void:
	assert_eq(Cost.max_affordable(EXP, 0, 0.0), 0)
