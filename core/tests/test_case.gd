class_name TestCase
extends RefCounted
## Classe base per i test. Estendila e scrivi metodi che iniziano con `test_`.
##
##   extends TestCase
##
##   func test_somma() -> void:
##       assert_eq(2 + 2, 4)
##
## Il runner (core/tests/run_tests.gd) trova i file `*_test.gd` sotto res://tests/
## ed esegue automaticamente tutti i metodi `test_*`.

var _failures: Array[String] = []


## Chiamato prima di ogni metodo `test_*`. Sovrascrivilo per preparare lo stato.
func before_each() -> void:
	pass


## Chiamato dopo ogni metodo `test_*`.
##
## Se in before_each hai creato oggetti a cui hai connesso delle lambda, azzerali
## qui (`oggetto = null`): lambda e istanza di test si tengono a vicenda e Godot
## segnalerebbe "ObjectDB instances leaked" a fine run.
func after_each() -> void:
	pass


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not _values_equal(actual, expected):
		_fail("atteso %s, ottenuto %s" % [_fmt(expected), _fmt(actual)], msg)


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if _values_equal(actual, unexpected):
		_fail("non doveva essere %s" % _fmt(unexpected), msg)


func assert_true(value: bool, msg: String = "") -> void:
	if not value:
		_fail("atteso true", msg)


func assert_false(value: bool, msg: String = "") -> void:
	if value:
		_fail("atteso false", msg)


func assert_null(value: Variant, msg: String = "") -> void:
	if value != null:
		_fail("atteso null, ottenuto %s" % _fmt(value), msg)


func assert_not_null(value: Variant, msg: String = "") -> void:
	if value == null:
		_fail("atteso non-null", msg)


## Confronto per float con tolleranza. Usalo sempre al posto di assert_eq sui float.
func assert_almost(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		_fail("atteso ~%f (±%f), ottenuto %f" % [expected, eps, actual], msg)


func assert_gt(actual: float, threshold: float, msg: String = "") -> void:
	if actual <= threshold:
		_fail("atteso > %f, ottenuto %f" % [threshold, actual], msg)


func assert_lt(actual: float, threshold: float, msg: String = "") -> void:
	if actual >= threshold:
		_fail("atteso < %f, ottenuto %f" % [threshold, actual], msg)


func assert_has(container: Variant, key: Variant, msg: String = "") -> void:
	if not (key in container):
		_fail("%s non contiene %s" % [_fmt(container), _fmt(key)], msg)


## Fallimento esplicito, per rami di codice che non dovrebbero essere raggiunti.
func fail(msg: String) -> void:
	_fail(msg, "")


func _fail(detail: String, msg: String) -> void:
	_failures.append(detail if msg.is_empty() else "%s — %s" % [msg, detail])


## Usato dal runner. Restituisce e azzera i fallimenti accumulati.
func take_failures() -> Array[String]:
	var out := _failures.duplicate()
	_failures.clear()
	return out


func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return a == b


func _fmt(v: Variant) -> String:
	if v is String:
		return '"%s"' % v
	return str(v)
