class_name CardLibrary
extends RefCounted
## Il ponte fra i JSON e le carte: mette insieme seme, valore ed eventuale
## carattere speciale, e sa costruire un mazzo intero da una ricetta.
##
## Nessuno istanzia questa classe: sono tutte funzioni statiche.
##
##   CardLibrary.build("picche_c7")
##   CardLibrary.generate(rng, {"deck_size": 14, "weights": {"poker": 1.0}})

## Le famiglie non sono più due e non stanno più qui: sono righe di
## `game/data/families.json`, e l'ordine di quel file è l'ordine in cui vengono
## pesate. **Non riordinarlo a cuor leggero**: cambia la sequenza di estrazioni
## dello stream e con essa ogni partita riprodotta da un seed.
static func families() -> Array:
	return Content.list("families")


## Solo le famiglie che possono comparire in bottega, negli avversari, nelle
## reliquie e negli eventi. Una famiglia a metà (semi senza effetti, livelli
## evolutivi che non si comprano) esiste nei dati ma sta fuori di qui.
static func pool_families() -> Array:
	return Content.filter("families", func(entry: Dictionary) -> bool:
		return bool(entry.get("in_pool", true))
	)


## Costruisce la carta con quell'id ("picche_c7"). Null se seme o valore non esistono.
static func build(card_id: String) -> Card:
	var parts := card_id.split("_", false, 1)
	if parts.size() != 2:
		push_error("CardLibrary: id malformato '%s' (atteso <seme>_<valore>)" % card_id)
		return null
	return build_from(parts[0], parts[1])


static func build_from(suit_id: String, rank_id: String) -> Card:
	if not Content.has("suits", suit_id) or not Content.has("ranks", rank_id):
		push_error("CardLibrary: carta inesistente '%s_%s'" % [suit_id, rank_id])
		return null

	var suit := Content.entry("suits", suit_id)
	var rank := Content.entry("ranks", rank_id)
	# Un valore da poker su un seme di briscola (o viceversa) non è una carta
	# rotta: è una carta che non esiste. Warning, non errore.
	if not is_valid_pair(suit, rank):
		push_warning("CardLibrary: '%s' e '%s' non fanno una carta" % [suit_id, rank_id])
		return null

	var card_id := "%s_%s" % [suit_id, rank_id]
	var special: Dictionary = Content.entry("specials", card_id) if Content.has("specials", card_id) else {}
	return Card.new(suit, rank, special)


## Tutte le carte **costruibili**. Serve ai test di integrità e al manuale: qui
## dentro c'è anche ciò che il giocatore non può comprare.
static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for suit in Content.list("suits"):
		for rank in Content.list("ranks"):
			if is_valid_pair(suit, rank):
				out.append("%s_%s" % [suit.get("id", ""), rank.get("id", "")])
	return out


## Le carte che possono davvero finire in mano al giocatore. È la lista su cui si
## misurano prezzi e bilanciamento: un livello evolutivo che si ottiene solo in
## battaglia, o una famiglia ancora senza effetti, falserebbe ogni media.
static func pool_ids() -> Array[String]:
	var famiglie: Array[String] = []
	for family in pool_families():
		famiglie.append(String(family.get("id", "")))

	var out: Array[String] = []
	for suit in Content.list("suits"):
		if not bool(suit.get("in_pool", true)) or not String(suit.get("family", "")) in famiglie:
			continue
		for rank in Content.list("ranks"):
			if bool(rank.get("in_pool", true)) and is_valid_pair(suit, rank):
				out.append("%s_%s" % [suit.get("id", ""), rank.get("id", "")])
	return out


## Se quel seme e quel valore fanno una carta. Di norma basta la famiglia; le
## carte fuori seme (il Joker, L'antigh) si tengono per sé il proprio valore
## dichiarandolo da entrambe le parti.
static func is_valid_pair(suit: Dictionary, rank: Dictionary) -> bool:
	if String(suit.get("family", "")) != String(rank.get("family", "")):
		return false

	var soli_rank: Array = suit.get("rank_ids", [])
	if not soli_rank.is_empty() and not String(rank.get("id", "")) in soli_rank:
		return false
	var soli_semi: Array = rank.get("suit_ids", [])
	if not soli_semi.is_empty() and not String(suit.get("id", "")) in soli_semi:
		return false
	return true


static func suits_of(family: String, only_pool: bool = false) -> Array:
	return Content.filter("suits", func(entry: Dictionary) -> bool:
		if only_pool and not bool(entry.get("in_pool", true)):
			return false
		return String(entry.get("family", "")) == family
	)


## I valori di una famiglia, filtrati per intervallo (estremi inclusi).
static func ranks_of(family: String, low: int = 1, high: int = 99, only_pool: bool = false) -> Array:
	return Content.filter("ranks", func(entry: Dictionary) -> bool:
		if only_pool and not bool(entry.get("in_pool", true)):
			return false
		var v := int(entry.get("value", 0))
		return String(entry.get("family", "")) == family and v >= low and v <= high
	)


## Da una lista di id a un mazzo di carte vere. Gli id sconosciuti vengono saltati.
static func deck_from_ids(ids: Array) -> Array[Card]:
	var out: Array[Card] = []
	for raw in ids:
		var card := build(String(raw))
		if card != null:
			out.append(card)
	return out


## Una carta a caso, seguendo i pesi delle famiglie e l'intervallo di valori.
## Tutta la casualità passa dallo stream: stesso seed, stesso mazzo.
##
## Una ricetta che nomina le famiglie che vuole **esclude tutte le altre**: è la
## regola che tiene gli avversari già scritti al riparo dalle famiglie che
## arriveranno dopo di loro. Una ricetta senza pesi usa i `default_weight`.
static func random_card(rng: RngStream, weights: Dictionary = {}, value_range: Array = []) -> Card:
	var nomi: Array = []
	var pesi: Array = []
	var totale := 0.0
	for family in pool_families():
		var id := String(family.get("id", ""))
		var peso: float = (
			float(weights.get(id, 0.0)) if not weights.is_empty()
			else float(family.get("default_weight", 1.0))
		)
		nomi.append(id)
		pesi.append(peso)
		totale += maxf(peso, 0.0)

	if nomi.is_empty():
		return null
	# Una ricetta che azzera tutto non deve restare senza carte: si ricade sui
	# pesi di default invece di restituire null e assottigliare il mazzo.
	if totale <= 0.0:
		for i in nomi.size():
			pesi[i] = float(Content.entry("families", nomi[i]).get("default_weight", 1.0))

	var family_id := String(rng.pick_weighted(nomi, pesi))

	var low := int(value_range[0]) if value_range.size() > 0 else 1
	var high := int(value_range[1]) if value_range.size() > 1 else 99
	var carte := _pool_pairs(family_id, low, high)
	if carte.is_empty():
		carte = _pool_pairs(family_id, 1, 99)
	if carte.is_empty():
		return null

	# Si estrae **una carta**, non un seme e poi un valore. Con le carte fuori
	# seme — il Jolly, L'antigh — le due estrazioni indipendenti producevano
	# coppie che non esistono, e ogni volta il mazzo usciva più corto di quanto
	# la ricetta prometteva. In più, così un seme che ha una carta sola pesa una
	# carta sola invece di un quarto del mazzo.
	var scelta: Array = rng.pick(carte)
	return build_from(String(scelta[0]), String(scelta[1]))


## Le coppie seme+valore che esistono davvero in quella famiglia e in quella
## fascia di valori, fra quelle comprabili.
static func _pool_pairs(family: String, low: int, high: int) -> Array:
	var out: Array = []
	for suit in suits_of(family, true):
		for rank in ranks_of(family, low, high, true):
			if is_valid_pair(suit, rank):
				out.append([String(suit.get("id", "")), String(rank.get("id", ""))])
	return out


## Un mazzo intero da ricetta: quante carte, con che mescolanza di famiglie, in
## che fascia di valori. È così che nascono gli avversari, una riga di JSON l'uno.
static func generate(rng: RngStream, recipe: Dictionary) -> Array[Card]:
	var out: Array[Card] = []
	var size := int(recipe.get("deck_size", 12))
	var weights: Dictionary = recipe.get("weights", {})
	var value_range: Array = recipe.get("value_range", [])
	var seals: Array = recipe.get("seals", [])

	# Ogni quante carte ne esce una sigillata. Uno su tre è il ritmo normale: un
	# avversario tutto sigillato non si legge più, e non insegna niente. Il
	# Fabbro è l'eccezione che conferma — è tutto il suo personaggio.
	var seal_every := maxi(int(recipe.get("seal_every", 3)), 1)
	var seals_per_card := maxi(int(recipe.get("seals_per_card", 1)), 1)
	## Bonus che valgono per tutto il mazzo dell'avversario, con lo stesso
	## vocabolario dei passivi della run: è così che il Contadino gioca carte
	## piccole che valgono più di quello che c'è scritto sopra.
	var rules: Array = recipe.get("rules", [])

	for i in maxi(size, 0):
		var card := random_card(rng, weights, value_range)
		if card == null:
			continue

		if not seals.is_empty() and i % seal_every == 0:
			for volta in seals_per_card:
				var seal_id := String(rng.pick(seals))
				if Content.has("seals", seal_id):
					card.add_seal(Content.entry("seals", seal_id))

		for rule in rules:
			if rule is Dictionary:
				apply_rule(card, rule)

		out.append(card)
	return out


## Applica a una carta una regola del vocabolario dei passivi: filtri
## `family` · `suit` · `tag` · `value_min` · `value_max`, effetti `value_add` ·
## `value_mult` · `cooldown_scale`.
##
## Sta qui e non in `RunState` perché la usano tutti e due — le reliquie del
## giocatore e i mazzi degli avversari — e due copie della stessa regola
## divergono al primo filtro nuovo.
static func apply_rule(card: Card, rule: Dictionary, source: String = "run") -> void:
	if card == null:
		return
	if rule.has("family") and String(rule["family"]) != card.family:
		return
	if rule.has("suit") and String(rule["suit"]) != card.suit_id:
		return
	if rule.has("tag") and not card.has_tag(String(rule["tag"])):
		return
	# Le soglie si leggono sul valore **nudo**, non su quello già gonfiato da
	# un'altra regola: altrimenti l'ordine in cui si applicano cambierebbe tutto.
	if rule.has("value_min") and card.stats.get_base("value") < float(rule["value_min"]):
		return
	if rule.has("value_max") and card.stats.get_base("value") > float(rule["value_max"]):
		return

	if rule.has("value_add"):
		card.stats.add_mod("value", StatBlock.FLAT, float(rule["value_add"]), source)
	if rule.has("value_mult"):
		card.stats.add_mod("value", StatBlock.MULT, float(rule["value_mult"]), source)
	if rule.has("cooldown_scale"):
		card.cooldown_scale *= float(rule["cooldown_scale"])
