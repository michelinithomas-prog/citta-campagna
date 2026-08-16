class_name Card
extends RefCounted
## Una carta: un seme più un valore, e nient'altro.
##
## L'effetto non è scritto sulla carta ma **dedotto**: il seme dice cosa fa
## (danno, cura, scudo, oro), il valore dice quanto fa e quanto si fa aspettare.
## Con otto semi e ventitré valori vengono novantadue carte da otto righe di JSON.
##
## Il valore vive dentro uno StatBlock, non in una variabile: così gli effetti
## possono leggerlo con la forma dinamica che EffectResolver già conosce
## ({"stat": "value", "of": "card"}) e i sigilli che potenziano sono normali
## modificatori, senza una riga di codice dedicata.
##
##   var carta := CardLibrary.build("picche_c7")
##   carta.interval()     # 4.1 secondi di attesa
##   carta.value()        # 7

const MAX_SEALS := 2
const MIN_INTERVAL := 0.4

# Le `source` dei modificatori temporanei. Sono tre e **non una**: `remove_source`
# lavora in blocco, quindi se il buff dello slot e quello del Re condividessero
# l'etichetta, sostituire il primo cancellerebbe anche il secondo.
#
#   MOD_SLOT    il buff del posto: cambia quando cambia il buff
#   MOD_MATCH   il bonus fino a fine battaglia (il Re)
#   MOD_BATTLE  il debuff una tantum (i Bastoni sui valori avversari)
#
# Le tre muoiono insieme in reset_for_battle(). Sopravvive solo "run", che sono
# i passivi della partita e valgono anche fuori dalla battaglia.
const MOD_SLOT := "slot"
const MOD_MATCH := "match"
const MOD_BATTLE := "battle"
const MOD_TEMPORANEE := [MOD_SLOT, MOD_MATCH, MOD_BATTLE]

## Come si legge un effetto sulla faccia della carta.
## Le parole scritte sotto la faccia di ogni carta.
# i18n
const EFFECT_LABELS := {
	"damage": "danni",
	"heal": "cura",
	"shield": "scudo",
	"gold": "oro",
	"burn": "brucia",
	"slow": "rallenta",
	"haste": "affretta",
	"recycle": "torna nel mazzo",
	"bleed": "sanguinamento",
	"poison": "veleno",
	"cleanse": "ripulisce",
	"paralyze": "paralizza",
	"slot_buff": "potenzia lo slot",
	"match_buff": "danni fino a fine match",
	"value_debuff": "indebolisce",
	"mill": "scarta dal mazzo",
	"recover": "recupera",
	"steal": "ruba una carta",
	"spawn_card": "aggiunge al mazzo",
	"combo": "catena",
	"combo_reset": "spegne la catena",
}

## "1 danni" si legge male, e sulle carte di valore basso capita spesso.
## Le stesse al singolare: «1 danno», non «1 danni».
# i18n
const EFFECT_LABELS_ONE := {
	"damage": "danno",
	"gold": "moneta",
	"burn": "brucia",
	"mill": "scarta dal mazzo",
	"recover": "recupera",
}

## Le caratteristiche di base di una carta. Non sono campi: si **deducono** dagli
## effetti, così il numero stampato sulla faccia non può divergere da quello che
## la battaglia esegue. Tutto ciò che non rientra qui è "effetto speciale".
const STAT_KEYS := ["damage", "shield", "heal", "poison", "bleed", "gold"]

## I due tag che la combo di One interroga: chi porta un numero e chi vale per
## qualunque colore.
const NUMERO := "numero"
const JOLLY := "jolly"

## Come si scrivono in due caratteri e mezzo, quando lo spazio è quello che è.
# i18n
const STAT_SHORT := {
	"damage": "ATT",
	"shield": "SCU",
	"heal": "CUR",
	"poison": "VEL",
	"bleed": "SAN",
	"gold": "ORO",
}

## Serve solo a leggere i valori dinamici per il testo della carta: nessun
## handler registrato, quindi non trattiene niente e non va mai ripulito.
static var _reader := EffectResolver.new()

var id := ""
var suit_id := ""
var rank_id := ""
var display_name := ""
var symbol := ""
var short := ""
var family := ""
var color_key := ""
var text := ""

var stats: StatBlock
## Cosa fa quando si attiva.
var effects: Array = []
## Cosa fa **ogni secondo che passa in plancia**, aspettando. Sono gli effetti
## marcati `"when": "tick"`, separati qui una volta sola invece di essere
## rifiltrati venti volte al secondo dentro la battaglia.
var tick_effects: Array = []
## Cosa fa **appena entra in plancia**, prima ancora di cominciare ad aspettare
## (`"when": "enter"`). È così che la carta Blocco spegne la combo di One.
var enter_effects: Array = []
var seals: Array[Dictionary] = []

## L'id del valore in cui questa carta si trasforma dopo essersi attivata, se ne
## ha uno. È una proprietà del valore, non un effetto: un effetto potrebbe
## essere cancellato da un `"replace": true` in specials.json, e l'evoluzione
## sparirebbe senza che nessuno se ne accorga.
var evolves_to := ""

## Da quale carta del mazzo della run viene questa copia — il suo posto in
## `RunState.collection`, o -1 se è nata dentro la battaglia (un Germoglio, la
## creatura dell'Antigh, una carta rubata).
##
## Serve a una cosa sola, ma importante: **l'evoluzione dura per il resto della
## partita**, e per riportarla nel mazzo bisogna sapere quale delle tre copie
## identiche di Sgorga è cresciuta. Il nome non basta, l'oggetto nemmeno: ogni
## battaglia gioca con cloni.
var origin := -1

## Il colore agli occhi della catena di One: "rosso", "giallo", "verde", "blu".
## Non è il colore con cui la carta viene disegnata — è un'appartenenza, e passa
## da un mazzo all'altro: Cuori e Quadri sono rosse quanto il Rosso di One, e
## infatti la catena la fanno partire anche loro.
var combo_color := ""

## Le etichette con cui i bonus la riconoscono: "figura", "rossa", "animale",
## più quelle dedotte da seme, mazzo e valore.
var tags: Array[String] = []

## L'attesa nuda della carta, prima dei sigilli. Deriva da seme e valore.
var cooldown_base := 1.0
## Moltiplicatore dei bonus passivi della run (es. "le carte città sono più svelte").
var cooldown_scale := 1.0
## Quanto manca all'attivazione. Vive solo dentro una battaglia.
var cooldown := 0.0

## Contatori che valgono per una battaglia sola (quante volte è già stata
## riciclata, per esempio). Non serve azzerarli: ogni battaglia gioca con cloni.
var uses: Dictionary = {}

var _interval := 1.0


func _init(suit: Dictionary = {}, rank: Dictionary = {}, special: Dictionary = {}) -> void:
	suit_id = String(suit.get("id", ""))
	rank_id = String(rank.get("id", ""))
	id = "%s_%s" % [suit_id, rank_id]

	symbol = String(suit.get("symbol", "?"))
	short = String(rank.get("short", "?"))
	family = String(suit.get("family", "poker"))
	color_key = String(suit.get("color", "accent"))
	# "Asso di Picche", ma non "Jolly di Jolly": le carte fuori seme hanno un
	# nome solo, ed è già scritto due volte nei dati perché seme e valore
	# esistono solo per loro.
	var nome_seme := String(suit.get("name", "?"))
	var nome_valore := String(rank.get("name", "?"))
	display_name = nome_seme if nome_seme == nome_valore else "%s di %s" % [nome_valore, nome_seme]
	text = String(suit.get("text", ""))

	stats = StatBlock.new({"value": float(rank.get("value", 1))})

	evolves_to = String(rank.get("evolves_to", ""))
	combo_color = String(suit.get("combo_color", ""))

	# L'attesa nasce dal seme e cresce col valore; il valore può aggiungerne
	# ancora (un Re si fa aspettare). Si calcola **una volta sola**, sul valore
	# nudo: un sigillo che potenzia la carta ne aumenta l'effetto ma non l'attesa.
	var cooldown_cfg: Dictionary = suit.get("cooldown", {})
	cooldown_base = maxf(
		float(cooldown_cfg.get("base", 1.0))
			+ value() * float(cooldown_cfg.get("per_value", 0.0))
			+ float(rank.get("cooldown_add", 0.0)),
		MIN_INTERVAL
	)

	# Seme e valore fanno la carta insieme: l'effetto del seme *più* quello del
	# numero. È la regola che rende "Cinque di Cuori" una carta e non due.
	effects = (suit.get("effects", []) as Array).duplicate(true)
	for effect in rank.get("effects", []):
		if effect is Dictionary:
			effects.append((effect as Dictionary).duplicate(true))

	if not special.is_empty():
		_apply_special(special)

	_build_tags(suit, rank, special)
	_split_tick_effects()
	_recompute()


## I tag di una carta: quelli scritti nei JSON più quelli che si deducono da
## soli. Servono ai bonus che parlano di gruppi di carte ("le figure", "le
## rosse") senza doverle elencare una per una.
func _build_tags(suit: Dictionary, rank: Dictionary, special: Dictionary) -> void:
	tags.clear()
	for source in [suit, rank, special]:
		for tag in source.get("tags", []):
			var testo := String(tag)
			if not testo.is_empty() and not testo in tags:
				tags.append(testo)

	for automatico in [
		"mazzo:%s" % family,
		"seme:%s" % suit_id,
		"valore:%d" % value(),
		"pari" if value() % 2 == 0 else "dispari",
	]:
		if not automatico in tags:
			tags.append(automatico)


func has_tag(tag: String) -> bool:
	return tag in tags


## Se **questa carta**, entrando in uno slot, allunga la catena sulla carta che
## ne è appena uscita. La direzione conta: `entrata.combos_with(uscita)`.
##
## La catena è la meccanica di One, e **la fa partire One**: `uscita` deve venire
## da un mazzo che la dichiara (`"combo": true` in `families.json`). Chi entra
## invece può venire da qualunque mazzo — un Cuori rosso si aggancia a un Rosso
## di One, ed è la ragione per cui un mazzo di One tiene volentieri qualche
## figura di poker.
##
## Senza questo vincolo la catena partiva **da sola nel primo round**: il Baro
## gioca poker, il poker ha due semi rossi, e due carte rosse di fila bastavano.
## Trentacinque battaglie su quaranta con una meccanica che il giocatore non ha
## ancora visto e non ha modo di capire.
##
## Il legame è sul colore o sul numero. Il Cambia Colore sta bene con qualunque
## colore ma non ha un numero con cui legarsi; lo Zero colpisce come un Dieci ma
## per la catena è uno zero, perché il confronto è sull'**id del valore** e non
## sul numero che quel valore vale. (Lo stesso vale per i potenziamenti: un
## sigillo non deve poter creare o spezzare una catena.)
func combos_with(other: Card) -> bool:
	if other == null:
		return false
	if not bool(other.family_entry().get("combo", false)):
		return false

	# Il **colore** attraversa i mazzi: chi entra può arrivare da dove vuole.
	var mio_jolly := has_tag(JOLLY)
	var suo_jolly := other.has_tag(JOLLY)
	var io_coloro := mio_jolly or not combo_color.is_empty()
	var lui_colora := suo_jolly or not other.combo_color.is_empty()
	if io_coloro and lui_colora:
		if mio_jolly or suo_jolly or combo_color == other.combo_color:
			return true

	# Il **numero** invece resta in casa: un Sette di poker e un Sette di One
	# sono una coincidenza, non una catena.
	if family != other.family:
		return false
	return rank_id == other.rank_id and has_tag(NUMERO) and other.has_tag(NUMERO)


## Separa una volta per tutte i tre momenti in cui una carta può fare qualcosa:
## quando entra in plancia, mentre aspetta, e quando si attiva. Rifiltrare a
## runtime costerebbe venti passate al secondo per carta, e questo elenco non
## cambia più dopo la costruzione — salvo un sigillo, che infatti richiama
## questa funzione.
func _split_tick_effects() -> void:
	var restano: Array = []
	for effect in effects:
		match String(effect.get("when", "")) if effect is Dictionary else "":
			"tick":
				tick_effects.append(effect)
			"enter":
				enter_effects.append(effect)
			_:
				restano.append(effect)
	effects = restano


## Le carte con carattere: o si aggiungono all'effetto del seme, o lo sostituiscono.
func _apply_special(special: Dictionary) -> void:
	if bool(special.get("replace", false)):
		effects = []
	for effect in special.get("effects", []):
		if effect is Dictionary:
			effects.append((effect as Dictionary).duplicate(true))

	if special.has("name"):
		display_name = String(special["name"])
	if special.has("text"):
		text = String(special["text"])
	if special.has("cooldown_add"):
		cooldown_base = maxf(cooldown_base + float(special["cooldown_add"]), MIN_INTERVAL)
	# Una linea evolutiva può finire prima delle altre: l'elettro si ferma al
	# secondo livello. È l'unico modo per dirlo, perché `evolves_to` sta sul
	# valore e il valore è in comune fra i quattro semi.
	if special.has("evolves_to"):
		evolves_to = String(special["evolves_to"])


func value() -> int:
	return stats.get_stat_int("value")


## Quanto vale un effetto di questa carta, adesso. Passa dallo stesso resolver
## che userà la battaglia, così il numero scritto sulla carta e il numero che
## arriva in faccia all'avversario non possono divergere.
func amount_of(effect: Dictionary) -> int:
	return int(roundf(_amount_float(effect)))


func _amount_float(effect: Dictionary) -> float:
	return _reader.value(effect, "amount", {"card": self}, 0.0)


## Le sei caratteristiche di base più il conteggio degli effetti speciali.
## I meta-effetti si risolvono al **valore atteso**: una `chance` 0.5 su sei
## danni conta tre. È l'unico modo di confrontare fra loro carte che tirano dadi
## e carte che non lo fanno, e serve tanto alla faccia della carta quanto a
## `tests/budget_test.gd`.
## Sotto `"tick"` finisce quello che la carta fa **ogni secondo** stando ferma in
## plancia: è una grandezza diversa, e sommarla all'altra farebbe sembrare un
## seme d'erba una bomba.
func stat_line() -> Dictionary:
	var out := _riga_vuota()
	out["tick"] = _riga_vuota()
	walk_effects(func(effect: Dictionary, weight: float) -> void:
		_conta(effect, weight, out)
	)
	if not tick_effects.is_empty():
		walk_effects(func(effect: Dictionary, weight: float) -> void:
			_conta(effect, weight, out["tick"])
		, tick_effects)
	if not enter_effects.is_empty():
		walk_effects(func(effect: Dictionary, weight: float) -> void:
			_conta(effect, weight, out)
		, enter_effects)
	return out


func _riga_vuota() -> Dictionary:
	var out := {"special": 0, "utility": {}}
	for key in STAT_KEYS:
		out[key] = 0.0
	return out


## Scorre l'albero degli effetti risolvendo i meta al **valore atteso** — una
## `chance` 0.5 su sei danni pesa tre — e chiama `visita(effetto, peso)` su ogni
## foglia.
##
## Esiste una volta sola perché i suoi due lettori devono essere d'accordo: la
## faccia della carta e il metro del bilanciamento leggono lo stesso albero con
## la stessa idea di cosa vuol dire "in media". Due visite separate divergono al
## primo effetto annidato, e nessuno se ne accorge finché non è tardi.
func walk_effects(visita: Callable, lista: Variant = null) -> void:
	_walk(lista if lista is Array else effects, 1.0, visita)


func _walk(list: Array, weight: float, visita: Callable) -> void:
	for raw in list:
		if not raw is Dictionary:
			continue
		var effect: Dictionary = raw
		match String(effect.get("type", "")):
			"all":
				_walk(effect.get("effects", []), weight, visita)
			"repeat":
				var times := maxf(_reader.value(effect, "times", {"card": self}, 1.0), 0.0)
				_walk([effect.get("effect", {})], weight * times, visita)
			"chance":
				var p := clampf(_reader.value(effect, "p", {"card": self}, 0.5), 0.0, 1.0)
				_walk([effect.get("effect", {})], weight * p, visita)
				if effect.has("else"):
					_walk([effect["else"]], weight * (1.0 - p), visita)
			"random":
				var options: Array = effect.get("effects", [])
				var weights: Array = effect.get("weights", [])
				var total := 0.0
				for i in options.size():
					total += float(weights[i]) if i < weights.size() else 1.0
				if total <= 0.0:
					continue
				for i in options.size():
					var w: float = float(weights[i]) if i < weights.size() else 1.0
					_walk([options[i]], weight * w / total, visita)
			_:
				visita.call(effect, weight)


func _conta(effect: Dictionary, weight: float, out: Dictionary) -> void:
	var type := String(effect.get("type", ""))
	if type.is_empty():
		return

	if not type in STAT_KEYS:
		out["special"] += 1
		# I verbi di utilità non hanno una statistica, ma hanno un peso: chi
		# bilancia deve poterli contare, o metà delle carte sembrerà che non
		# facciano niente e finirà sotto il costo che merita.
		var quanto: Dictionary = out["utility"]
		quanto[type] = float(quanto.get(type, 0.0)) + weight * _quantita(effect)
		return

	var amount := weight * _amount_float(effect)
	# Un colpo che punti su di te è un costo, non un guadagno: nel conto va col
	# segno meno, altrimenti le Picche sembrano gratis.
	if String(effect.get("target", "")) == "self" and type != "gold":
		amount = -amount
	out[type] += amount


## Quanto "pesa" un verbo di utilità, in unità sue: i secondi di un rallentamento,
## le carte di uno scarto, gli slot toccati da un potenziamento. Chi lo traduce
## in punti è `CardBudget`; qui si conta soltanto.
func _quantita(effect: Dictionary) -> float:
	match String(effect.get("type", "")):
		"recycle":
			return maxf(_reader.value(effect, "times", {"card": self}, 1.0), 0.0)
		"paralyze":
			var secondi := maxf(_reader.value(effect, "amount", {"card": self}, 1.0), 0.0)
			return secondi * (5.0 if bool(effect.get("all", false)) else 1.0)
		"slot_buff":
			return _peso_del_buff(effect)
		"steal", "cleanse":
			return 1.0
		_:
			var quanto := absf(_amount_float(effect))
			return quanto if quanto > 0.0 else 1.0


## Un buff di slot vale per quanti slot tocca e per quanto dà a ciascuno. Il
## lifesteal pesa più di un punto di valore perché si riscuote a ogni colpo di
## ogni carta che passerà da lì.
func _peso_del_buff(effect: Dictionary) -> float:
	var buff: Dictionary = effect.get("buff", {})
	var slots := 5.0 if String(effect.get("slots", "self")) in ["all", "others"] else 1.0
	var forza := float(buff.get("value_add", 0.0))
	forza += float(buff.get("lifesteal", 0.0)) * 3.0
	forza += maxf(1.0 - float(buff.get("cooldown_mult", 1.0)), 0.0) * 5.0
	forza += maxf(float(buff.get("value_mult", 1.0)) - 1.0, 0.0) * 3.0
	return slots * forza


## Il testo che la carta mostra: "7 danni", "3 oro · 4 danni".
func effect_text() -> String:
	var parts: Array[String] = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		var type := String((effect as Dictionary).get("type", ""))
		if not EFFECT_LABELS.has(type):
			parts.append(tr(String(effect.get("text", type))))
			continue
		var amount := amount_of(effect)
		# L'etichetta è la parola, e si traduce **qui**, dove si mostra: la
		# costante resta la chiave. Lo scheletro "%d %s" invece non è una frase —
		# `tools/estrai_testi.py` lo tiene fuori dal catalogo apposta — e un tr()
		# lì non troverebbe mai niente da cercare.
		if amount == 0 and not effect.has("amount"):
			parts.append(tr(String(EFFECT_LABELS[type])))
		elif amount == 1 and EFFECT_LABELS_ONE.has(type):
			parts.append("1 %s" % tr(String(EFFECT_LABELS_ONE[type])))
		else:
			parts.append("%d %s" % [amount, tr(String(EFFECT_LABELS[type]))])
	return " · ".join(parts)


## La versione corta, per il log e per la faccia della carta: solo le
## caratteristiche diverse da zero. Con seme e valore che sommano i loro effetti
## una carta ne ha quattro o cinque, e `effect_text()` diventa un paragrafo.
func short_text() -> String:
	var line := stat_line()
	var parts: Array[String] = []
	for key in STAT_KEYS:
		var amount := int(roundf(float(line[key])))
		if amount != 0:
			parts.append("%d %s" % [amount, tr(String(STAT_SHORT[key]))])
	var extra := int(line["special"])
	if extra > 0:
		parts.append("+%d" % extra)
	return " · ".join(parts) if not parts.is_empty() else effect_text()


## L'attesa vera, sigilli e passivi inclusi.
func interval() -> float:
	return maxf(_interval * cooldown_scale, MIN_INTERVAL)


## Applica un sigillo. Falso se la carta è già piena: due sono il massimo, oltre
## non si legge più cosa fa.
func add_seal(seal: Dictionary) -> bool:
	if seals.size() >= MAX_SEALS or seal.is_empty():
		return false

	seals.append(seal.duplicate(true))
	if seal.has("value_mult"):
		stats.add_mod("value", StatBlock.MULT, float(seal["value_mult"]), "seal")
	for effect in seal.get("extra_effects", []):
		if effect is Dictionary:
			effects.append((effect as Dictionary).duplicate(true))

	_split_tick_effects()
	_recompute()
	return true


func seal_ids() -> Array[String]:
	var out: Array[String] = []
	for seal in seals:
		out.append(String(seal.get("id", "")))
	return out


func has_seal(seal_id: String) -> bool:
	return seal_id in seal_ids()


## Rimette la carta in condizione di partire. Da chiamare quando entra in plancia.
## Toglie **tutti** i modificatori temporanei: una carta che rientra dal riciclo
## non deve portarsi dietro il buff di prima, e un debuff non deve sopravvivere
## al ripescaggio. Chi la accoglie (`Side._apply_slot_state`) rimette subito
## quelli che spettano al posto e alla partita.
func reset_for_battle() -> void:
	for source in MOD_TEMPORANEE:
		stats.remove_source(source)
	_recompute()
	cooldown = interval()


## La riga di `families.json` a cui questa carta appartiene. Vuota se la famiglia
## non è dichiarata: succede solo con dati incompleti, e chi legge deve reggerlo.
func family_entry() -> Dictionary:
	return Content.entry("families", family) if Content.has("families", family) else {}


## Una copia indipendente: il mazzo della run non deve sentire quello che
## succede alle carte durante una battaglia.
func clone() -> Card:
	var copy := Card.new()
	copy.id = id
	copy.suit_id = suit_id
	copy.rank_id = rank_id
	copy.display_name = display_name
	copy.symbol = symbol
	copy.short = short
	copy.family = family
	copy.color_key = color_key
	copy.text = text
	copy.stats = stats.clone()
	copy.effects = effects.duplicate(true)
	copy.tick_effects = tick_effects.duplicate(true)
	copy.enter_effects = enter_effects.duplicate(true)
	copy.evolves_to = evolves_to
	copy.origin = origin
	copy.combo_color = combo_color
	copy.tags = tags.duplicate()
	copy.cooldown_base = cooldown_base
	copy.cooldown_scale = cooldown_scale
	copy.cooldown = cooldown
	for seal in seals:
		copy.seals.append(seal.duplicate(true))
	copy._recompute()
	return copy


# --- persistenza ---------------------------------------------------------
#
# Una carta è seme + valore + i sigilli che le sono stati messi addosso. Tutto
# il resto (nome, effetti, attesa, testo) è dedotto dai JSON: salvarlo
# significherebbe congelare un bilanciamento vecchio dentro il salvataggio, e
# ritrovarselo in campo dopo aver toccato `suits.json`. Si salvano tre id.

func to_dict() -> Dictionary:
	var ids: Array = []
	for seal in seals:
		ids.append(String(seal.get("id", "")))
	return {"suit": suit_id, "rank": rank_id, "seals": ids}


## Ricostruisce la carta dai dati e le rimette i sigilli. Null se il seme o il
## valore non esistono più: un salvataggio vecchio non deve far esplodere niente,
## quella carta semplicemente non torna nel mazzo.
static func from_dict(data: Dictionary) -> Card:
	var suit := String(data.get("suit", ""))
	var rank := String(data.get("rank", ""))
	if not Content.has("suits", suit) or not Content.has("ranks", rank):
		return null

	var card := CardLibrary.build_from(suit, rank)
	if card == null:
		return null

	for raw in data.get("seals", []):
		var seal_id := String(raw)
		if Content.has("seals", seal_id):
			card.add_seal(Content.entry("seals", seal_id))
	return card


func _recompute() -> void:
	var multiplier := 1.0
	var addition := 0.0
	for seal in seals:
		multiplier *= float(seal.get("cooldown_mult", 1.0))
		addition += float(seal.get("cooldown_add", 0.0))
	_interval = maxf(cooldown_base * multiplier + addition, MIN_INTERVAL)
