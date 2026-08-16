extends SceneTree
## Scrive i tre manuali del gioco leggendoli dai dati veri.
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/genera_manuale.gd
##
## Produce docs/carte.md, docs/eventi.md, docs/reliquie-e-innesti.md.
##
## Sono generati, non scritti: un manuale battuto a mano diverge dal gioco al
## primo ritocco di bilanciamento, e nessuno se ne accorge finché qualcuno non
## ci gioca. Dopo aver toccato i JSON, rilancialo.

const DIR := "res://docs"

var _cfg: Node
var _content: Node
## Caricati a runtime, non per nome: le classi del gioco usano gli autoload, che
## non esistono ancora quando questo script viene compilato (è lui il MainLoop).
var _lib: GDScript
var _card: GDScript
var _budget: GDScript


func _initialize() -> void:
	_cfg = root.get_node("Cfg")
	_content = root.get_node("Content")
	_lib = load("res://game/logic/card_library.gd")
	_card = load("res://game/logic/card.gd")
	_budget = load("res://game/logic/budget.gd")


## Si scrive al primo frame, non in _initialize: lì gli autoload esistono come
## nodi ma non hanno ancora eseguito il loro _ready, quindi Content è vuoto e i
## manuali uscirebbero senza una carta dentro.
func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_scrivi("carte.md", _manuale_carte())
	_scrivi("eventi.md", _manuale_eventi())
	_scrivi("reliquie-e-innesti.md", _manuale_reliquie())
	_scrivi("avversari.md", _manuale_avversari())
	quit(0)
	return true


func _scrivi(nome: String, testo: String) -> void:
	var path := "%s/%s" % [DIR, nome]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("non riesco a scrivere %s" % path)
		return
	file.store_string(testo)
	file.close()
	print("scritto: %s (%d righe)" % [path, testo.split("\n").size()])


func _intestazione(titolo: String, sottotitolo: String) -> String:
	return "# %s\n\n> %s\n>\n> Generato da `tools/genera_manuale.gd` — non modificarlo a mano:\n> alla prossima rigenerazione le modifiche spariscono. Cambia i JSON in `game/data/`.\n\n" % [titolo, sottotitolo]


# --- carte ---------------------------------------------------------------

func _manuale_carte() -> String:
	var out := _intestazione(
		"Le carte",
		"Ogni carta è un seme più un valore. Il seme dice cosa fa, il valore quanto fa e quanto si fa aspettare."
	)

	out += "## Come si legge una carta\n\n"
	out += "L'effetto non è scritto carta per carta: si **somma**. Il seme dice cosa\n"
	out += "sa fare la carta (`effetto = valore × moltiplicatore`), il numero ci\n"
	out += "aggiunge il suo — lo stesso su tutti i mazzi — e alcune carte hanno per\n"
	out += "giunta un effetto scritto a mano.\n\n"
	out += "Le sigle: **ATT** attacco · **SCU** scudo · **CUR** cura · **VEL** veleno ·\n"
	out += "**SAN** sanguinamento · **ORO** oro. Il `+n` finale conta gli effetti che\n"
	out += "un numero non ce l'hanno: rubare, paralizzare, allungare la catena.\n\n"
	out += "I *punti al secondo* sono il metro con cui le carte si confrontano fra\n"
	out += "loro (`game/logic/budget.gd`): un punto vale un danno, e tutto il resto\n"
	out += "— scudo, cura, oro, veleno, tempo rubato — è convertito in quello.\n\n"

	# Le famiglie e i loro nomi vengono dai dati: aggiungere un mazzo non deve
	# richiedere di venire a modificare il generatore del manuale.
	for family in _content.list("families"):
		if not bool(family.get("in_pool", true)):
			continue  # un mazzo ancora senza effetti non si documenta

		var famiglia := String(family.get("id", ""))
		out += "\n---\n\n# %s\n\n" % family.get("label", family.get("name", famiglia))
		if family.has("text"):
			out += "*%s*\n\n" % family["text"]

		for suit in _content.list("suits"):
			if String(suit.get("family", "")) != famiglia:
				continue
			out += _sezione_seme(suit)

	out += "\n---\n\n## Le carte con carattere\n\n"
	out += "Queste hanno un effetto in più (o al posto di) quello del seme.\n\n"
	out += "| Carta | Cosa fa in più |\n|---|---|\n"
	for special in _content.list("specials"):
		out += "| **%s** | %s |\n" % [
			special.get("name", special.get("id", "?")),
			special.get("text", "—"),
		]

	return out


func _sezione_seme(suit: Dictionary) -> String:
	var id := String(suit.get("id", ""))
	var cooldown: Dictionary = suit.get("cooldown", {})

	var out := "## %s %s\n\n" % [suit.get("symbol", ""), suit.get("name", id)]
	out += "*%s*\n\n" % suit.get("text", "")
	out += "Attesa: **%.1fs + %.2fs per punto di valore**\n\n" % [
		float(cooldown.get("base", 0.0)), float(cooldown.get("per_value", 0.0))
	]
	out += "| Carta | Cosa fa | Attesa | Punti al secondo |\n|---|---|---|---|\n"

	for rank in _content.list("ranks"):
		if String(rank.get("family", "")) != String(suit.get("family", "")):
			continue
		if not _lib.is_valid_pair(suit, rank):
			continue
		var card: Object = _lib.build_from(id, String(rank.get("id", "")))
		if card == null:
			continue

		# `short_text()` e non `effect_text()`: adesso una carta ha quattro o
		# cinque effetti fra seme e valore, e per esteso diventano una riga che
		# non si legge — "1 danno · 0 danni · 1 danno" invece di "2 ATT".
		# I punti al secondo vengono dallo stesso metro del bilanciamento, così
		# il manuale e i test dicono lo stesso numero.
		out += "| %s %s — %s | %s | %.1fs | %.2f |\n" % [
			card.symbol, card.short, card.display_name,
			card.short_text(), card.interval(), _budget.punti_al_secondo(card),
		]

	return out + "\n"


# --- avversari -----------------------------------------------------------

func _manuale_avversari() -> String:
	var out := _intestazione(
		"Gli avversari",
		"Uno per vittoria. Chi perde se lo ritrova davanti: è il conteggio delle vittorie a farli avanzare."
	)

	out += "Nessuno di loro gioca *un* mazzo — finiscono tutti nello stesso — ma\n"
	out += "ognuno ha una preferenza forte, e si riconosce dopo dieci secondi di\n"
	out += "battaglia. Le percentuali qui sotto sono i pesi con cui pesca le carte.\n\n"

	out += "| # | Avversario | Vita | Scudo | Mazzo | Valori | Poker | Briscola | One | Gaiofanamon |\n"
	out += "|---:|---|---:|---:|---:|:---:|---:|---:|---:|---:|\n"

	var numero := 0
	for entry in _content.list("opponents"):
		numero += 1
		var pesi: Dictionary = entry.get("weights", {})
		var totale := 0.0
		for chiave in pesi:
			totale += maxf(float(pesi[chiave]), 0.0)

		var quote: Array[String] = []
		for famiglia in ["poker", "briscola", "one", "gaiofanamon"]:
			var peso := float(pesi.get(famiglia, 0.0))
			quote.append("%d%%" % int(round(peso / totale * 100.0)) if totale > 0.0 else "—")

		var fascia: Array = entry.get("value_range", [])
		out += "| %d | **%s** | %d | %d | %d | %s | %s | %s | %s | %s |\n" % [
			numero, entry.get("name", entry.get("id", "?")),
			int(entry.get("hp", 0)), int(entry.get("shield", 0)), int(entry.get("deck_size", 0)),
			("%d-%d" % [int(fascia[0]), int(fascia[1])]) if fascia.size() > 1 else "tutti",
			quote[0], quote[1], quote[2], quote[3],
		]

	out += "\n"
	for entry in _content.list("opponents"):
		out += "\n---\n\n## %s\n\n" % entry.get("name", entry.get("id", "?"))
		out += "> %s\n\n" % entry.get("text", "")

		var extra: Array[String] = []
		if entry.has("rules"):
			for rule in entry["rules"]:
				extra.append("le sue carte hanno un bonus: `%s`" % JSON.stringify(rule))
		if entry.has("seals"):
			var ogni := int(entry.get("seal_every", 3))
			var quanti := int(entry.get("seals_per_card", 1))
			extra.append("una carta ogni %d porta %d innest%s, presi fra: %s" % [
				ogni, quanti, "o" if quanti == 1 else "i", ", ".join(entry["seals"]),
			])
		if not extra.is_empty():
			out += "- " + "\n- ".join(extra) + "\n"

	return out


# --- eventi --------------------------------------------------------------

func _manuale_eventi() -> String:
	var out := _intestazione(
		"Gli incontri",
		"Capitano fra una battaglia e l'altra, non al primo round e non sempre. Ogni incontro esce una volta sola per partita."
	)

	out += "Probabilità che ne capiti uno: **%d%%** per round, dal round **%d** in poi.\n\n" % [
		int(_cfg.get_float("events.chance", 0.5) * 100.0),
		_cfg.get_int("events.min_round", 2),
	]

	for event in _content.list("events"):
		out += "\n---\n\n## %s\n\n" % event.get("name", event.get("id", "?"))
		out += "*Dal round %d in poi.*\n\n" % int(event.get("min_round", 1))
		out += "> %s\n\n" % event.get("text", "")

		for choice in event.get("choices", []):
			out += "### %s\n\n" % choice.get("label", "?")
			if choice.has("hint"):
				out += "*Promette: %s*\n\n" % choice["hint"]
			var conseguenze := _descrivi_effetti(choice.get("effects", []))
			out += ("- " + "\n- ".join(conseguenze) + "\n\n") if not conseguenze.is_empty() \
				else "- Non succede niente.\n\n"

	return out


## Traduce un albero di effetti in righe leggibili, `chance` e `random` compresi.
func _descrivi_effetti(effects: Array) -> Array[String]:
	var righe: Array[String] = []
	for effect in effects:
		if effect is Dictionary:
			righe.append_array(_descrivi_effetto(effect))
	return righe


func _descrivi_effetto(effect: Dictionary) -> Array[String]:
	var tipo := String(effect.get("type", ""))
	var righe: Array[String] = []

	match tipo:
		"chance":
			var p := int(float(effect.get("p", 0.5)) * 100.0)
			for riga in _descrivi_effetto(effect.get("effect", {})):
				righe.append("**%d%% delle volte**: %s" % [p, riga])
			if effect.has("else"):
				for riga in _descrivi_effetto(effect["else"]):
					righe.append("**il restante %d%%**: %s" % [100 - p, riga])
		"random":
			var opzioni: Array = effect.get("effects", [])
			var pesi: Array = effect.get("weights", [])
			var totale := 0.0
			for i in opzioni.size():
				totale += float(pesi[i]) if i < pesi.size() else 1.0
			for i in opzioni.size():
				var peso: float = float(pesi[i]) if i < pesi.size() else 1.0
				for riga in _descrivi_effetto(opzioni[i]):
					righe.append("**a sorte (%d%%)**: %s" % [int(peso / totale * 100.0), riga])
		"all":
			righe.append_array(_descrivi_effetti(effect.get("effects", [])))
		_:
			righe.append(_descrivi_singolo(effect, tipo))

	return righe


func _descrivi_singolo(effect: Dictionary, tipo: String) -> String:
	var quanto := int(effect.get("amount", 0))
	match tipo:
		"run_gold":
			return "%+d oro" % quanto
		"run_max_hp":
			return "%+d di vita massima" % quanto
		"run_life":
			return "%+d %s" % [quanto, "vita" if absi(quanto) == 1 else "vite"]
		"run_relic":
			if effect.has("relic"):
				var rid := String(effect["relic"])
				var reliquia: Dictionary = _content.entry("relics", rid) if _content.has("relics", rid) else {}
				return "in tasca la reliquia **%s**" % reliquia.get("name", rid)
			return "una reliquia a caso, fra quelle che non hai"
		"run_end":
			return "**la partita finisce qui**"
		"run_next_battle":
			return String(effect.get("text", "qualcosa te lo porti nella prossima battaglia"))
		"run_swap_suit":
			return "scambia una tua carta di %s con un'altra dello stesso stadio" % effect.get("family", "quella famiglia")
		"run_add_card":
			if effect.has("card"):
				var carta: Object = _lib.build(String(effect["card"]))
				return "aggiunge al mazzo: **%s**" % (carta.display_name if carta != null else effect["card"])
			var dettagli: Array[String] = []
			if effect.has("family"):
				var id := String(effect["family"])
				var family: Dictionary = _content.entry("families", id) if _content.has("families", id) else {}
				dettagli.append("di %s" % family.get("name", id))
			if effect.has("value_range"):
				var r: Array = effect["value_range"]
				dettagli.append("di valore %d-%d" % [int(r[0]), int(r[1])])
			return "una carta in più nel mazzo%s" % (" (%s)" % " ".join(dettagli) if not dettagli.is_empty() else "")
		"run_remove_card":
			var n := maxi(quanto, 1)
			return "toglie %d cart%s dal mazzo, a caso" % [n, "a" if n == 1 else "e"]
		"run_seal":
			var seal_id := String(effect.get("seal", ""))
			var seal: Dictionary = _content.entry("seals", seal_id) if _content.has("seals", seal_id) else {}
			return "mette il sigillo **%s** su una carta a caso" % seal.get("name", seal_id)
		"run_passive":
			return "per tutta la partita: %s" % effect.get("text", "un bonus")
		_:
			return "effetto `%s`" % tipo


# --- reliquie e sigilli --------------------------------------------------

func _manuale_reliquie() -> String:
	var out := _intestazione(
		"Reliquie e innesti",
		"Due cose diverse: l'innesto si posa su una carta sola, la reliquia vale per tutta la partita."
	)

	out += "## Reliquie\n\n"
	out += "Si comprano in bottega, **una copia sola per partita**, e non si perdono più.\n"
	out += "In vetrina ne compaiono %d per round.\n\n" % _cfg.get_int("shop.relic_offers", 2)
	out += "| Reliquia | Costo | Cosa fa |\n|---|---|---|\n"
	for relic in _content.list("relics"):
		out += "| **%s** | %d oro | %s |\n" % [
			relic.get("name", "?"), int(relic.get("cost", 0)), relic.get("text", "—")
		]

	out += "\n### Attenzione a due di queste\n\n"
	out += "- **Il Banco del Mercato** dà un posto in più sulla plancia. Più carte in campo\n"
	out += "  vuol dire più effetti al secondo, ma anche un mazzo che si consuma più in fretta:\n"
	out += "  è un acceleratore, non un potenziamento. Con un mazzo corto ti ammazza.\n"
	out += "- **La Bisaccia** è il contrario: due carte in più sono due giri di respiro\n"
	out += "  contro l'esaurimento, anche se le carte in sé sono mediocri.\n\n"

	out += "\n---\n\n## Innesti\n\n"
	out += "Si posano su **una carta** del mazzo, al massimo **%d per carta**.\n" % int(_card.MAX_SEALS)
	out += "In vetrina ne compaiono %d per round.\n\n" % _cfg.get_int("shop.seal_offers", 2)
	out += "| Innesto | Costo | Cosa fa |\n|---|---|---|\n"
	for seal in _content.list("seals"):
		out += "| **%s** | %d oro | %s |\n" % [
			seal.get("name", "?"), int(seal.get("cost", 0)), seal.get("text", "—")
		]

	return out
