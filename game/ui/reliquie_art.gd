class_name ReliquieArt
extends RefCounted
## Trova l'icona di una reliquia.
##
## Qui la convenzione è una sola e senza eccezioni — `<id>.png`, l'id è quello di
## `relics.json` — quindi non serve la mappa dei nomi che `CarteArt` deve tenere
## per i mazzi. Il file si chiama come la reliquia: se la reliquia cambia id,
## anche il file deve cambiare nome, e `data_test` se ne accorge.
##
## Come per le carte, chi non ha un'icona non è un errore: `per_reliquia`
## restituisce null e chi chiama tiene il posto in un altro modo. Le reliquie
## nascono prima dei loro disegni, e una jam non aspetta.
##
## Il risultato è in cache per lo stesso motivo di `CarteArt`: `load()` su una
## texture già letta costa poco, ma `ResourceLoader.exists()` su un file che non
## c'è tocca il disco ogni volta, e la vetrina si ridisegna a ogni acquisto.

const CARTELLA := "res://game/art/reliquie"

static var _cache: Dictionary = {}


static func per_id(relic_id: String) -> Texture2D:
	if relic_id.is_empty():
		return null
	if _cache.has(relic_id):
		return _cache[relic_id]

	var percorso := "%s/%s.png" % [CARTELLA, relic_id]
	var texture: Texture2D = load(percorso) if ResourceLoader.exists(percorso) else null
	_cache[relic_id] = texture
	return texture


static func per_reliquia(relic: Dictionary) -> Texture2D:
	return per_id(String(relic.get("id", "")))


## Da chiamare a mano quando i file cambiano sotto i piedi: F5 ricarica i dati,
## e senza questo le icone resterebbero quelle di prima.
static func dimentica() -> void:
	_cache.clear()
