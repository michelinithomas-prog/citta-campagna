extends Node
## Salvataggio su user://save.json.
##
##   Save.set_value("audio.music", 0.5)
##   Save.get_value("best.score", 0)
##   Save.record_best("score", 1200)     # true se è un nuovo record
##
## Le scritture sono raggruppate: set_value non tocca il disco subito ma
## programma un flush, così si può chiamare a ogni frame senza pensarci.
## Sul web il salvataggio va nell'IndexedDB del browser: funziona uguale.

const SAVE_PATH := "user://save.json"
const VERSION := 1
const AUTOSAVE_DELAY := 1.0

signal saved
signal loaded

var data: Dictionary = {}

var _dirty := false
var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_file()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer -= delta
	if _timer <= 0.0:
		flush()


func _notification(what: int) -> void:
	# Chiusura della finestra o dell'app: non perdere l'ultima modifica.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			flush()


# --- lettura e scrittura ------------------------------------------------

func get_value(path: String, default_value: Variant = null) -> Variant:
	var node: Variant = data
	for key in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(key):
			return default_value
		node = (node as Dictionary)[key]
	return node


func set_value(path: String, value: Variant) -> void:
	var keys := path.split(".")
	var node: Dictionary = data
	for i in keys.size() - 1:
		if not (node.get(keys[i]) is Dictionary):
			node[keys[i]] = {}
		node = node[keys[i]]
	node[keys[keys.size() - 1]] = value
	mark_dirty()


func has(path: String) -> bool:
	return get_value(path) != null


func erase(path: String) -> void:
	var keys := path.split(".")
	var node: Dictionary = data
	for i in keys.size() - 1:
		if not (node.get(keys[i]) is Dictionary):
			return
		node = node[keys[i]]
	node.erase(keys[keys.size() - 1])
	mark_dirty()


## Registra un record solo se migliore. Restituisce true se è un nuovo primato.
func record_best(key: String, value: float) -> bool:
	var path := "best." + key
	if value <= float(get_value(path, -INF)):
		return false
	set_value(path, value)
	return true


func mark_dirty() -> void:
	_dirty = true
	_timer = AUTOSAVE_DELAY


# --- disco --------------------------------------------------------------

func flush() -> void:
	_dirty = false
	data["_version"] = VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Save: impossibile scrivere %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	saved.emit()


func load_file() -> void:
	data = {}
	if not FileAccess.file_exists(SAVE_PATH):
		loaded.emit()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Save: impossibile leggere %s" % SAVE_PATH)
		loaded.emit()
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		# Un salvataggio corrotto non deve impedire di giocare: si riparte puliti.
		push_warning("Save: salvataggio illeggibile, riparto da zero")
		loaded.emit()
		return

	data = json.data
	loaded.emit()


## Cancella tutto (comando di debug `reset`).
func wipe() -> void:
	data = {}
	flush()
