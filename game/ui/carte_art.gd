class_name CarteArt
extends RefCounted
## Trova il disegno di una carta.
##
## Le tre famiglie hanno tre convenzioni di nome diverse, ereditate da come sono
## stati preparati i mazzi:
##
##   briscola      card_<seme>_<valore>.png     card_denari_re.png, card_coppe_7.png
##   poker         card_<valore>_<seme>.png     card_K_S.png, card_10_H.png
##   one           card_<colore-inglese>_<n>.png  card_red_5.png, card_blue_plus2.png
##   gaiofanamon   <Nome>.png                   Zappin.png, SgorgaDaBon.png
##
## **La cartella si chiama come la famiglia in `families.json`.** Non è un
## dettaglio: quando la famiglia dei mostri è stata ribattezzata da "porkemon" a
## "gaiofanamon" e la cartella è rimasta indietro, le carte hanno smesso di avere
## un disegno tutte insieme e in silenzio — `per_carta` restituisce null e chi
## chiama regge il caso, quindi non c'è nessun errore da leggere.
##
## Invece di piegare i file alle convenzioni del codice (o viceversa), la mappa
## sta qui: è l'unico punto da toccare se arriva un mazzo con un'altra logica di
## nomi, e i JSON del gioco restano intatti.
##
## Il risultato è in cache: `load()` su una texture già caricata è economico, ma
## `ResourceLoader.exists()` su una carta che non c'è tocca il disco ogni volta,
## e in battaglia si ridisegna sessanta volte al secondo.

const CARTELLA := "res://game/art/carte"

## Il retro, per gli slot vuoti e per la pila.
const RETRO := {
	"briscola": "res://game/art/carte/briscola/card_back.png",
	"poker": "res://game/art/carte/poker/card_back.png",
}

## Da valore numerico a come si chiama nel nome del file, per la briscola.
const VALORI_BRISCOLA := {8: "fante", 9: "cavallo", 10: "re"}

## Da seme a lettera, per il poker (Spades, Hearts, Diamonds, Clubs).
const SEMI_POKER := {"picche": "S", "cuori": "H", "quadri": "D", "fiori": "C"}

## I quattro colori di One, che sul disco parlano inglese.
const COLORI_ONE := {"rosso": "red", "giallo": "yellow", "verde": "green", "blu": "blue"}

## I valori di One che non sono un numero. `q0` e `w0` non hanno colore: il loro
## disegno è la carta jolly, uguale per tutti.
##
## Un Dieci non c'è, e non deve esserci: **lo Zero fa il lavoro del Dieci** —
## colpisce come lui — ma per la catena resta uno zero, e ha il disegno dello
## zero. Il `reverse` su disco resta inutilizzato come la sua meccanica.
##
## Il Blocco non passa da qui: ha un file suo (`one/blocco_b0.png`, lo `skip` in
## grigio) perché **non ha colore**, e vestirlo di rosso lo farebbe sembrare una
## carta che allunga la catena proprio mentre la spegne.
const VALORI_ONE := {"d2": "plus2", "w0": "wild", "q0": "wild_plus4"}

## Le carte che non seguono nessuna regola: `<id della carta>: <nome del file>`,
## dentro la cartella della sua famiglia.
##
## I gaiofanamon ci stanno tutti, perché i loro file portano il nome che il
## disegnatore ha dato alla creatura, e quel nome sull'apostrofo e sulle
## abbreviazioni non coincide con quello scritto nei dati — `E' Canon` sta su
## disco come `Canon.png`, `L'antigh` come `Antig.png`. Il Jolly ci sta perché
## la regola del poker compone valore e seme, e lui un seme non ce l'ha.
##
## Una mappa esplicita dice la verità; una regola che ci prova indovina undici
## volte su dodici e lascia una carta bianca senza dirlo.
const SPRITE_PER_CARTA := {
	"acqua_g1": "Sgorga", "acqua_g2": "SgorgaDaBon", "acqua_g3": "Canon",
	"erba_g1": "Zappin", "erba_g2": "Zappoun", "erba_g3": "Zappador",
	"fuoco_g1": "Scintela", "fuoco_g2": "Fughett", "fuoco_g3": "Drag",
	"elettro_g1": "Sorc", "elettro_g2": "Rataz",
	"antigh_a0": "Antig",
	"jolly_j0": "joker_colored",
}

static var _cache: Dictionary = {}


## Il disegno di questa carta, o null se non ne ha uno: chi chiama deve reggere
## il caso — non tutte le famiglie hanno gli sprite, e durante una jam ne
## arrivano a pezzi.
static func per_carta(card: Card) -> Texture2D:
	if card == null:
		return null
	if _cache.has(card.id):
		return _cache[card.id]

	var texture: Texture2D = null
	for percorso in _candidati(card):
		if ResourceLoader.exists(percorso):
			texture = load(percorso)
			break

	_cache[card.id] = texture
	return texture


## I percorsi da provare, in ordine di preferenza. Più di uno perché una carta
## speciale può avere un disegno suo che vince su quello del seme.
static func _candidati(card: Card) -> Array[String]:
	var out: Array[String] = []
	var famiglia := _famiglia(card)

	# Un disegno dedicato a questa carta esatta, se esiste: prima il file che
	# porta il suo id, poi la mappa delle eccezioni. Vengono prima di ogni regola
	# — è così che una carta si prende un disegno suo senza discutere.
	out.append("%s/%s/%s.png" % [CARTELLA, famiglia, card.id])
	if SPRITE_PER_CARTA.has(card.id):
		out.append("%s/%s/%s.png" % [CARTELLA, famiglia, SPRITE_PER_CARTA[card.id]])

	match famiglia:
		"briscola":
			out.append("%s/briscola/card_%s_%s.png" % [CARTELLA, card.suit_id, _valore_briscola(card)])
		"poker":
			var seme := String(SEMI_POKER.get(card.suit_id, ""))
			if seme != "":
				out.append("%s/poker/card_%s_%s.png" % [CARTELLA, card.short, seme])
		"one":
			out.append_array(_candidati_one(card))
		_:
			# Gaiofanamon e le famiglie che verranno: il file porta il nome della
			# creatura. La mappa qui sopra copre le eccezioni; questo copre le
			# carte che arriveranno senza toccare il codice — si prova il nome
			# così com'è e senza spazi, perché "Sgorga Da Bon" sta su disco come
			# SgorgaDaBon.png.
			out.append("%s/%s/%s.png" % [CARTELLA, famiglia, card.display_name])
			out.append("%s/%s/%s.png" % [CARTELLA, famiglia, card.display_name.replace(" ", "")])
			out.append("%s/%s/%s.png" % [CARTELLA, famiglia, card.rank_id])
	return out


## One mette il colore nel nome del file e il valore in coda: `card_red_5.png`.
## Le due jolly non hanno colore — una sola immagine vale per tutte — mentre le
## colorate compongono colore e valore.
static func _candidati_one(card: Card) -> Array[String]:
	var out: Array[String] = []
	var speciale := String(VALORI_ONE.get(card.rank_id, ""))

	if speciale == "wild" or speciale == "wild_plus4":
		out.append("%s/one/card_%s.png" % [CARTELLA, speciale])
		return out

	var colore := String(COLORI_ONE.get(card.suit_id, ""))
	if colore == "":
		return out

	# Il valore: o è uno dei nomi speciali, o è il numero stampato sulla carta.
	# `short` e non il valore di gioco: quello è la forza della carta, che il
	# bilanciamento può cambiare senza che il disegno debba seguirlo.
	var valore := speciale if speciale != "" else card.short
	out.append("%s/one/card_%s_%s.png" % [CARTELLA, colore, valore])
	return out


## La famiglia della carta, con un ripiego per quando `family` non è valorizzata.
static func _famiglia(card: Card) -> String:
	if card.family != "":
		return card.family
	return "poker" if SEMI_POKER.has(card.suit_id) else "briscola"


static func _valore_briscola(card: Card) -> String:
	var v := int(card.stats.get_base("value"))
	return String(VALORI_BRISCOLA.get(v, str(v)))


## Il dorso della famiglia, per gli slot vuoti.
static func retro(famiglia: String) -> Texture2D:
	var percorso := String(RETRO.get(famiglia, RETRO.get("briscola", "")))
	if percorso == "" or not ResourceLoader.exists(percorso):
		return null
	return load(percorso)


## Svuota la cache. Serve a F5: senza, dopo aver aggiunto un disegno il gioco
## continuerebbe a mostrare il buco che aveva trovato al primo giro.
static func dimentica() -> void:
	_cache.clear()
