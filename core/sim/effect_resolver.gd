class_name EffectResolver
extends RefCounted
## Il ponte fra i JSON di contenuto e il gioco.
##
## Un effetto è un dizionario con un campo "type". Ogni gioco registra gli
## handler che gli servono; il resolver ci aggiunge sopra i meta-effetti
## (sequenze, ripetizioni, probabilità) e la risoluzione dei valori dinamici,
## che sono uguali in tutti e quattro i generi.
##
##   resolver.register("damage", func(e, ctx):
##       ctx["target"].take_damage(resolver.value(e, "amount", ctx))
##   )
##   resolver.resolve({"type": "damage", "amount": 6}, {"target": nemico})
##
## AGGIUNGERE UN EFFETTO NUOVO IN JAM = una register() qui + una riga di JSON.
##
## Meta-effetti già pronti:
##   {"type": "all",    "effects": [ ... ]}                 in sequenza
##   {"type": "repeat", "times": 3, "effect": { ... }}      N volte
##   {"type": "chance", "p": 0.3, "effect": {...}, "else": {...}}
##   {"type": "random", "effects": [ ... ], "weights": [ ... ]}   uno solo
##
## Valori dinamici (ovunque ci si aspetti un numero):
##   6                                          costante
##   {"stat": "atk", "of": "source"}            legge una stat dal contesto
##   {"stat": "atk", "of": "source", "scale": 1.5, "add": 2}
##   {"random": [1, 6]}                         intero fra 1 e 6 (dallo stream seeded)

signal resolved(effect: Dictionary, context: Dictionary)

const META_TYPES := ["all", "repeat", "chance", "random"]

var rng: RngStream

var _handlers: Dictionary = {}


func _init(rng_stream: RngStream = null) -> void:
	rng = rng_stream if rng_stream != null else RngStream.new(1)


func register(type: String, handler: Callable) -> void:
	_handlers[type] = handler


## Da chiamare quando il resolver non serve più (fine partita, cambio scena).
## Gli handler tipicamente catturano il resolver stesso: senza questo si tengono
## a vicenda e nessuno dei due viene mai liberato.
func clear_handlers() -> void:
	_handlers.clear()


func has_handler(type: String) -> bool:
	return _handlers.has(type) or type in META_TYPES


func registered_types() -> Array:
	return _handlers.keys()


## Esegue un effetto. Restituisce quello che restituisce l'handler (spesso null).
func resolve(effect: Dictionary, context: Dictionary = {}) -> Variant:
	var type := String(effect.get("type", ""))

	match type:
		"all":
			return resolve_all(effect.get("effects", []), context)
		"repeat":
			var times := int(value(effect, "times", context, 1))
			var out := []
			for i in maxi(times, 0):
				out.append(resolve(effect.get("effect", {}), context))
			return out
		"chance":
			if rng.chance(float(value(effect, "p", context, 0.5))):
				return resolve(effect.get("effect", {}), context)
			elif effect.has("else"):
				return resolve(effect["else"], context)
			return null
		"random":
			var options: Array = effect.get("effects", [])
			if options.is_empty():
				return null
			var chosen: Variant = (
				rng.pick_weighted(options, effect["weights"])
				if effect.has("weights")
				else rng.pick(options)
			)
			return resolve(chosen if chosen != null else {}, context)

	if not _handlers.has(type):
		push_warning("EffectResolver: nessun handler per il tipo '%s' — effetto ignorato: %s" % [type, effect])
		return null

	var result: Variant = (_handlers[type] as Callable).call(effect, context)
	resolved.emit(effect, context)
	return result


func resolve_all(effects: Array, context: Dictionary = {}) -> Array:
	var out := []
	for e in effects:
		if e is Dictionary:
			out.append(resolve(e, context))
	return out


## Legge un campo numerico dell'effetto risolvendo le forme dinamiche.
func value(effect: Dictionary, key: String, context: Dictionary = {}, default_value: float = 0.0) -> float:
	if not effect.has(key):
		return default_value
	return resolve_value(effect[key], context, default_value)


func resolve_value(raw: Variant, context: Dictionary = {}, default_value: float = 0.0) -> float:
	match typeof(raw):
		TYPE_INT, TYPE_FLOAT:
			return float(raw)
		TYPE_BOOL:
			return 1.0 if raw else 0.0
		TYPE_DICTIONARY:
			var spec: Dictionary = raw
			if spec.has("random"):
				var bounds: Array = spec["random"]
				if bounds.size() == 2:
					return float(rng.randi_range(int(bounds[0]), int(bounds[1])))
				return default_value
			if spec.has("stat"):
				var owner_key := String(spec.get("of", "source"))
				var block := stat_block_of(context.get(owner_key))
				if block == null:
					return default_value
				var base := block.get_stat(String(spec["stat"]))
				return base * float(spec.get("scale", 1.0)) + float(spec.get("add", 0.0))
	return default_value


## Trova lo StatBlock di un oggetto del contesto: o è già uno StatBlock,
## o è un nodo/oggetto con una proprietà `stats`.
static func stat_block_of(owner: Variant) -> StatBlock:
	if owner is StatBlock:
		return owner
	if owner is Object and (owner as Object).get("stats") is StatBlock:
		return (owner as Object).get("stats")
	return null
