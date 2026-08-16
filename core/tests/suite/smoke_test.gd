extends TestCase
## Verifica che il core sia raggiungibile dal progetto (symlink o copia che sia).


func test_core_raggiungibile() -> void:
	assert_true(ResourceLoader.exists("res://core/tests/test_case.gd"))


func test_assert_almost_tollera_i_float() -> void:
	assert_almost(0.1 + 0.2, 0.3)
