extends SceneTree
## Test runner headless, zero dipendenze esterne.
##
##   godot --headless --path templates/<nome> --script res://core/tests/run_tests.gd
##
## Cerca i file `*_test.gd` sotto res://core/tests/suite/ e res://tests/, istanzia
## ogni classe (che deve estendere TestCase) ed esegue i suoi metodi `test_*`.
## Exit code 0 se passa tutto, 1 se almeno un test fallisce.
##
## Filtro opzionale: `-- <sottostringa>` esegue solo i file che la contengono.

const TEST_DIRS: Array[String] = ["res://core/tests/suite", "res://tests"]

const GREEN := "[32m"
const RED := "[31m"
const DIM := "[2m"
const BOLD := "[1m"
const OFF := "[0m"

## Quanti frame lasciar girare prima di partire. Serve perché gli autoload
## ricevono _ready() solo quando il tree processa il primo frame: partire da
## _initialize() significherebbe testarli non inizializzati.
const WARMUP_FRAMES := 2

var _passed := 0
var _failed := 0
var _failure_log: Array[String] = []
var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	_run_suite()
	return true


func _run_suite() -> void:
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		filter = user_args[0]

	var files: Array[String] = []
	for dir in TEST_DIRS:
		_collect(dir, files)
	files.sort()

	if filter != "":
		files = files.filter(func(f: String) -> bool: return filter in f)

	if files.is_empty():
		print("%sNessun file di test trovato.%s" % [RED, OFF])
		quit(1)
		return

	for path in files:
		_run_file(path)

	print("")
	if _failed == 0:
		print("%s%s✓ %d test passati%s" % [BOLD, GREEN, _passed, OFF])
	else:
		print("%s%s✗ %d falliti%s, %d passati" % [BOLD, RED, _failed, OFF, _passed])
		for line in _failure_log:
			print("  %s%s%s" % [RED, line, OFF])

	quit(0 if _failed == 0 else 1)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect(full, out)
		elif name.ends_with("_test.gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _run_file(path: String) -> void:
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		_fail_file(path.get_file(), "lo script non compila — vedi gli errori sopra")
		return

	var instance: Variant = script.new()
	if not (instance is TestCase):
		_fail_file(path.get_file(), "deve estendere TestCase")
		return

	var case := instance as TestCase
	var file_label := path.get_file().replace("_test.gd", "")
	print("%s%s%s" % [DIM, file_label, OFF])

	for method in case.get_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		if (method["args"] as Array).size() > 0:
			continue

		case.before_each()
		case.call(method_name)
		case.after_each()

		var failures := case.take_failures()
		if failures.is_empty():
			_passed += 1
			print("  %s✓%s %s" % [GREEN, OFF, method_name])
		else:
			_failed += 1
			print("  %s✗ %s%s" % [RED, method_name, OFF])
			for f in failures:
				print("      %s" % f)
				_record_failure(file_label, method_name, f)


func _record_failure(file_label: String, method_name: String, detail: String) -> void:
	_failure_log.append("%s :: %s — %s" % [file_label, method_name, detail])


## Un file che non compila conta come fallimento: senza questo la suite direbbe
## "tutto verde" semplicemente perché non ha eseguito niente.
func _fail_file(file_label: String, detail: String) -> void:
	_failed += 1
	print("%s✗ %s — %s%s" % [RED, file_label, detail, OFF])
	_record_failure(file_label, "<file>", detail)
