extends Node
## Carica i contenuti del gioco dai JSON in res://game/data/.
##
## Ogni file diventa una collezione che prende il nome dal file:
## cards.json -> Content.list("cards"). Il file tuning.json è escluso
## (quello lo gestisce Cfg).
##
## FORMATO: un array di oggetti, ognuno con un campo "id" univoco.
##
##   [
##     {"id": "strike", "name": "Colpo", "cost": 1, "effects": [...]},
##     {"id": "block",  "name": "Difesa", "cost": 1, "effects": [...]}
##   ]
##
## AGGIUNGERE CONTENUTO IN JAM = aggiungere una riga qui. Nessun codice.
##
## Gli errori di formato vengono stampati tutti insieme all'avvio, non a
## sorpresa a metà partita.

const DATA_DIR := "res://game/data/"
const EXCLUDED := ["tuning.json"]

## collection -> Array[Dictionary]
var _collections: Dictionary = {}
## collection -> {id: Dictionary}
var _by_id: Dictionary = {}
var _errors: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	_collections.clear()
	_by_id.clear()
	_errors.clear()

	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return  # un template senza contenuti è legittimo

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		# In esportazione i .json possono comparire come .json.remap
		var clean_name := file_name.trim_suffix(".remap")
		if not dir.current_is_dir() and clean_name.ends_with(".json") and clean_name not in EXCLUDED:
			_load_collection(clean_name.get_basename(), DATA_DIR + clean_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	for error in _errors:
		push_error("Content: %s" % error)

	Events.content_reloaded.emit()


func _load_collection(collection: String, path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("impossibile aprire %s" % path)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_errors.append("%s non è JSON valido — riga %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return
	if not (json.data is Array):
		_errors.append("%s deve contenere un array di oggetti" % path)
		return

	var entries: Array[Dictionary] = []
	var index: Dictionary = {}
	for raw in json.data as Array:
		if not (raw is Dictionary):
			_errors.append("%s: una voce non è un oggetto" % path)
			continue
		var entry: Dictionary = raw
		var id := String(entry.get("id", ""))
		if id.is_empty():
			_errors.append("%s: voce senza campo \"id\" — %s" % [path, entry])
			continue
		if index.has(id):
			_errors.append("%s: id duplicato \"%s\"" % [path, id])
			continue
		entries.append(entry)
		index[id] = entry

	_collections[collection] = entries
	_by_id[collection] = index


# --- lettura ------------------------------------------------------------

## Tutte le voci di una collezione, nell'ordine del file. SOLA LETTURA:
## per una copia modificabile usa instance().
func list(collection: String) -> Array:
	return _collections.get(collection, [])


func ids(collection: String) -> Array:
	return _by_id.get(collection, {}).keys()


## Una voce per id. Restituisce {} se non esiste, segnalandolo.
func entry(collection: String, id: String) -> Dictionary:
	var index: Dictionary = _by_id.get(collection, {})
	if not index.has(id):
		push_error('Content: "%s" non esiste in %s (disponibili: %s)' % [id, collection, ", ".join(ids(collection))])
		return {}
	return index[id]


## Copia profonda e modificabile: usala per creare l'istanza di gioco di una
## carta/unità/torre, così modificarla non altera i dati di partenza.
func instance(collection: String, id: String) -> Dictionary:
	return entry(collection, id).duplicate(true)


func has(collection: String, id: String) -> bool:
	return _by_id.get(collection, {}).has(id)


func collections() -> Array:
	return _collections.keys()


func count(collection: String) -> int:
	return list(collection).size()


## Voci che soddisfano una condizione: Content.filter("cards", func(c): return c.cost <= 1)
func filter(collection: String, predicate: Callable) -> Array:
	return list(collection).filter(predicate)


## Errori di caricamento, per mostrarli nell'overlay di debug.
func errors() -> Array[String]:
	return _errors
