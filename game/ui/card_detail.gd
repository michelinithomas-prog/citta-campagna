class_name CardDetail
extends PanelContainer
## La scheda che compare accanto a una carta quando ci passi sopra il mouse.
##
## Esiste perché la carta a schermo è larga 120 px: tutto quello che si scriveva
## sopra — nome, effetto, innesti — o copriva l'illustrazione o veniva spezzato a
## metà parola. Da qui in poi la faccia della carta mostra il disegno e l'attesa,
## e **tutto il resto si legge qui**, con lo spazio per scriverlo per esteso.
##
## Ce n'è **una sola** per schermata, creata da `play.gd` e riusata da ogni
## carta: costruirne una per carta significherebbe cinquanta pannelli vivi
## durante una battaglia. Per lo stesso motivo non tiene nessun riferimento alla
## `CardView` che l'ha aperta — quella può essere liberata da un `_clear()` da un
## momento all'altro, e un riferimento morto qui dentro sarebbe un errore dentro
## un handler di segnale.

## Larga abbastanza da far stare "Sanguinamento" e la spiegazione di un innesto
## senza spezzarle. Sotto i 240 px l'autowrap comincia a mandare a capo i nomi.
const LARGHEZZA := 260

## Le sei caratteristiche scritte per esteso: qui lo spazio c'è, e "ATT" lo si
## capisce solo dopo averlo già imparato altrove.
const NOME_STAT := {
	"damage": "Danni",
	"shield": "Scudo",
	"heal": "Cura",
	"poison": "Veleno",
	"bleed": "Sanguinamento",
	"gold": "Oro",
}

const COLORE_STAT := {
	"damage": Hud.DANNO,
	"shield": Hud.SCUDO,
	"heal": Hud.CURA,
	"poison": Hud.VELENO,
	"bleed": Hud.SANGUE,
	"gold": Hud.ORO,
}

## Il rettangolo della carta che l'ha aperta, in coordinate di viewport: la
## scheda ci si appoggia di fianco. È una copia, non un nodo: sopravvive alla
## carta anche se la carta muore.
var _ancora := Rect2()
## La carta di cui si sta mostrando la scheda. Serve solo a rispondere a
## `mostra_la_carta()`: la scheda non la interroga mai dopo averla disegnata, e
## non la tiene in vita — è già del `RunState` o della battaglia.
var _card: Card
## Se lo Shift è premuto adesso. La scheda si rifà **solo quando cambia**: il
## `_process` gira a ogni frame e ricostruirla ogni volta significherebbe
## sessanta ricostruzioni al secondo di una decina di Label.
var _shift := false


func _init() -> void:
	# `top_level` stacca la scheda dal contenitore che la ospita: così può
	# uscire dai bordi della bottega e appoggiarsi dove serve, in coordinate di
	# schermo. Lo z_index alto la tiene sopra a tutto il resto della scena.
	top_level = true
	z_index = 100
	visible = false
	# Non deve mai rubare il mouse: se lo facesse, aprendosi sotto al puntatore
	# toglierebbe l'hover alla carta, che la chiuderebbe, che glielo ridarebbe —
	# e la scheda lampeggerebbe all'infinito.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = LARGHEZZA
	add_theme_stylebox_override("panel", Hud.box(Hud.LEGNO, Hud.OTTONE, Hud.BORDO))
	set_process(false)


## Apre la scheda di questa carta di fianco a `ancora` (il rettangolo della carta
## a schermo, da `get_global_rect()`).
func mostra(card: Card, ancora: Rect2) -> void:
	if card == null:
		nascondi()
		return
	_ancora = ancora
	_card = card
	_shift = Input.is_key_pressed(KEY_SHIFT)
	_ricostruisci(card)
	visible = true
	set_process(true)


func nascondi() -> void:
	visible = false
	_card = null
	set_process(false)


## Vero se la scheda aperta è proprio quella di questa carta. Chi chiude la
## scheda lo chiede prima di farlo: passando da una carta all'altra i segnali
## arrivano al contrario (entra la nuova, poi esce la vecchia) e senza questa
## domanda la scheda appena aperta verrebbe chiusa dall'uscita della precedente.
func mostra_la_carta(card: Card) -> bool:
	return visible and _card == card


## La posizione si rifà a ogni frame finché la scheda è aperta, e non una volta
## sola all'apertura: appena costruita la scheda non conosce ancora la propria
## altezza — i contenitori la calcolano al frame dopo — e piazzarla subito la
## farebbe uscire dallo schermo in basso ogni volta che è alta.
func _process(_delta: float) -> void:
	var giu := Input.is_key_pressed(KEY_SHIFT)
	if giu != _shift:
		_shift = giu
		if _card != null:
			_ricostruisci(_card)

	var dim := get_combined_minimum_size()
	var schermo := get_viewport_rect().size

	# Di fianco alla carta, a destra; a sinistra se a destra non ci sta.
	var x := _ancora.position.x + _ancora.size.x + Hud.GAP
	if x + dim.x > schermo.x:
		x = _ancora.position.x - dim.x - Hud.GAP
	x = clampf(x, 0.0, maxf(schermo.x - dim.x, 0.0))

	# In alto allineata alla carta, ma senza mai sfondare il bordo di sotto.
	var y := clampf(_ancora.position.y, 0.0, maxf(schermo.y - dim.y, 0.0))

	global_position = Vector2(x, y)
	size = dim


func _ricostruisci(card: Card) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var righe: Array[Control] = []

	# --- chi è: seme, valore, nome, famiglia ---
	# Il glifo del seme non si traduce; sigla e nome sì, ma **solo qui**: nel
	# modello restano in italiano, perché `carte_art.gd` ci costruisce sopra il
	# nome del file del disegno.
	var titolo := Ui.label("%s %s  %s" % [card.symbol, tr(card.short), tr(card.display_name)],
		Hud.TESTO, colore_del_titolo(card))
	titolo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	righe.append(titolo)

	var famiglia := card.family_entry()
	if not famiglia.is_empty():
		righe.append(Ui.dim(String(famiglia.get("name", "")), Hud.TESTO_PICCOLO))

	# --- le etichette con cui i bonus la riconoscono ---
	var etichette := _etichette(card)
	if not etichette.is_empty():
		righe.append(_paragrafo(" · ".join(etichette).to_upper(), Hud.CREMA_MUTED, Hud.TESTO_PICCOLO))

	righe.append(_riga_separatrice())

	# --- quanto aspetta e quanto fa ---
	var numeri := Ui.grid(2, [], 2)
	numeri.add_child(Ui.dim("Attesa", Hud.TESTO_PICCOLO))
	numeri.add_child(_valore("%.1fs" % card.interval(), Hud.CREMA))

	var line := card.stat_line()
	for key in Card.STAT_KEYS:
		var amount := int(roundf(float(line[key])))
		if amount == 0:
			continue
		numeri.add_child(Ui.dim(String(NOME_STAT[key]), Hud.TESTO_PICCOLO))
		numeri.add_child(_valore(str(amount), COLORE_STAT[key]))
	righe.append(numeri)

	# --- cosa fa ogni secondo che sta ferma in plancia ---
	var a_tick := _riga_tick(line)
	if a_tick != "":
		righe.append(Ui.dim(tr("Ogni secondo: %s") % a_tick, Hud.TESTO_PICCOLO))

	# --- quello che un numero non ce l'ha: rubare, paralizzare, recuperare ---
	#
	# Qui **non** si rielenca il danno: sta già nella griglia qui sopra, sommato.
	# Prima si scriveva `effect_text()`, che stampa un effetto per riga così com'è
	# nei dati — e una carta che colpisce da due parti diventava "4 danni · 1
	# danno", due numeri da sommare a mente per sapere quanto fa davvero.
	var speciali := _righe_speciali(card, line)
	if not speciali.is_empty():
		righe.append(_riga_separatrice())
		for testo in speciali:
			righe.append(_paragrafo("• %s" % testo, Hud.CREMA))

	# --- gli innesti, con la loro spiegazione: sulla carta erano tre lettere ---
	if not card.seals.is_empty():
		righe.append(_riga_separatrice())
		for seal in card.seals:
			var nome_innesto := tr(String(seal.get("name", "?")))
			righe.append(Ui.label("◈ %s" % nome_innesto, Hud.TESTO_PICCOLO, Hud.ORO))
			righe.append(_paragrafo(String(seal.get("text", "")), Hud.CREMA_DIM, Hud.TESTO_PICCOLO))

	# --- e sotto SHIFT, come funzionano davvero le cose che questa carta fa ---
	#
	# Non sta sempre aperto perché sono paragrafi, e chi ha già imparato cos'è il
	# veleno non vuole rileggerselo cinquanta volte per battaglia. Ma chi non lo
	# sa deve poterlo scoprire **sulla carta che glielo sta facendo**, non in un
	# manuale da cercare altrove.
	var glossario := _glossario(card, line)
	if not glossario.is_empty():
		righe.append(_riga_separatrice())
		if _shift:
			for voce in glossario:
				righe.append(Ui.label(String(voce[0]), Hud.TESTO_PICCOLO, Hud.ORO))
				righe.append(_paragrafo(String(voce[1]), Hud.CREMA_DIM, Hud.TESTO_PICCOLO))
		else:
			righe.append(Ui.dim("SHIFT per come funziona", Hud.TESTO_PICCOLO))

	add_child(Ui.margin(Ui.vbox(righe, 2), Hud.PAD_SMALL))


## I quattro colori che una carta può avere, più il nero dei semi di poker.
## Sono gli stessi con cui si fa la catena di One: il colore di una carta è
## un'appartenenza, non una tinta scelta per fare bello — è il motivo per cui
## una Cuori e un Rosso di One si legano fra loro.
const COLORI := {
	"rosso": Hud.DANNO,
	"giallo": Hud.ORO,
	"verde": Hud.CURA,
	"blu": Hud.SCUDO,
}

## I tag che dichiarano un colore senza passare da `combo_color`: le carte di
## poker, che sono rosse o nere da prima che esistesse la catena.
const COLORI_DEI_TAG := {
	"rossa": "rosso",
	"nera": "nero",
}


## Di che colore va scritto il nome della carta.
##
## Il colore della carta, se ne ha uno — ed è quello vero, quello con cui fa
## catena, non la tinta del seme: le Quadri sono disegnate d'oro ma sono rosse, e
## chi cerca "una carta rossa" deve trovarle. Altrimenti neutro: la briscola un
## colore non ce l'ha, e dargliene uno a caso vorrebbe dire mentire.
static func colore_del_titolo(card: Card) -> Color:
	for tag in card.tags:
		if COLORI_DEI_TAG.has(tag):
			var nome := String(COLORI_DEI_TAG[tag])
			return Hud.NERO_CARTA if nome == "nero" else COLORI.get(nome, Hud.CREMA)

	if COLORI.has(card.combo_color):
		return COLORI[card.combo_color]
	return Hud.CREMA


## Le etichette da mostrare: solo quelle che dicono qualcosa a chi gioca.
##
## Restano fuori quelle con i due punti — `mazzo:poker`, `seme:picche`,
## `valore:10` — che servono ai bonus per pescare le carte giuste ma qui
## ripeterebbero tre cose già scritte due righe più su: la famiglia, il simbolo
## e il numero.
func _etichette(card: Card) -> Array[String]:
	var out: Array[String] = []
	for tag in card.tags:
		if not String(tag).contains(":"):
			# Tradotte qui e non nei dati: il tag resta l'id con cui i bonus
			# pescano le carte giuste, questa è solo la copia che si legge.
			out.append(tr(String(tag)))
	return out


## Un numero allineato a destra, così la colonna si legge in verticale.
func _valore(testo: String, colore: Color) -> Label:
	var l := Ui.label(testo, Hud.TESTO_PICCOLO, colore)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Un testo lungo che va a capo invece di allargare la scheda. Il minimo a 1 e
## non a 0 è lo stesso accorgimento di `CardView`: a zero il Label non ha una
## larghezza su cui calcolare gli a capo e il testo sparisce.
func _paragrafo(testo: String, colore: Color, misura: int = Hud.TESTO_PICCOLO) -> Label:
	var l := Ui.label(testo, misura, colore)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 1
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _riga_separatrice() -> Control:
	var riga := ColorRect.new()
	riga.color = Hud.OTTONE_SCURO
	riga.custom_minimum_size.y = 1
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return riga


## Quello che la carta fa **oltre** ai numeri: una riga per verbo, con la sua
## quantità già sommata. Se una carta ruba due volte, qui compare "ruba 2 carte",
## non due righe da leggere e mettere insieme a mente.
func _righe_speciali(card: Card, line: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var utility: Dictionary = line.get("utility", {})

	for verbo in VERBI:
		if not utility.has(verbo):
			continue
		var quanto := int(roundf(float(utility[verbo])))
		var frasi: Array = VERBI[verbo]
		# Alcuni verbi si contano (tre carte scartate), altri no: il buff di uno
		# slot ha una "forza" che non è un numero da mostrare a chi gioca. A dirlo
		# è la voce stessa — una frase o due — e non un flag da tenere allineato.
		if frasi.size() == 1:
			out.append(tr(String(frasi[0])))
		else:
			out.append(Testo.plurale(quanto, String(frasi[0]), String(frasi[1])) % quanto)

	# Chi mette carte nel mazzo deve dire **quali**: il Pesca Quattro ci infila
	# un Blocco, ed è il suo prezzo — scriverlo "aggiunge una carta" lo farebbe
	# sembrare un regalo.
	out.append_array(_carte_generate(card))

	# La crescita non è un dettaglio da tasto Shift: è il motivo per cui si compra
	# un cucciolo che da solo vale poco, e va letta prima di pagarlo.
	var dopo := _livello_dopo(card)
	if dopo != null:
		out.append(tr("Attivandosi diventa %s, per il resto della partita")
			% tr(dopo.display_name))

	return out


## Il livello successivo di questa creatura, se ne ha uno.
func _livello_dopo(card: Card) -> Card:
	if card.evolves_to.is_empty():
		return null
	return CardLibrary.build_from(card.suit_id, card.evolves_to)


## Cosa mette nel mazzo questa carta, già scritto per esteso.
##
## Un sacchetto di possibilità (`cards`) diventa **una riga sola** con l'elenco:
## L'antigh sveglia *una* creatura, e quattro righe "Mette X nel tuo mazzo" in
## fila farebbero credere che le metta tutte.
func _carte_generate(card: Card) -> Array[String]:
	var out: Array[String] = []
	var raccogli := func(effect: Dictionary, _peso: float) -> void:
		if String(effect.get("type", "")) != "spawn_card":
			return
		var nomi := _nomi_di(effect)
		if nomi.is_empty():
			return
		var riga := tr("Mette %s nel tuo mazzo") % nomi[0] if nomi.size() == 1 \
			else tr("Mette nel tuo mazzo una fra %s") % ", ".join(nomi)
		if not riga in out:
			out.append(riga)

	card.walk_effects(raccogli)
	# Le aure e gli effetti d'ingresso non generano carte oggi, ma il giorno che
	# lo faranno devono comparire qui come tutti gli altri.
	for lista in [card.tick_effects, card.enter_effects]:
		card.walk_effects(raccogli, lista)
	return out


## I nomi delle carte che un `spawn_card` può far nascere: una sola (`card`) o
## una qualsiasi del sacchetto (`cards`).
func _nomi_di(effect: Dictionary) -> Array[String]:
	var ids: Array = effect.get("cards", [])
	if ids.is_empty():
		ids = [effect.get("card", "")]

	var out: Array[String] = []
	for id in ids:
		if String(id).is_empty():
			continue
		var nata := CardLibrary.build(String(id))
		if nata == null:
			continue
		# Tradotto qui, dove il nome diventa testo da leggere: sulla carta resta
		# quello italiano, che è anche il nome del file del suo disegno.
		var nome := tr(nata.display_name)
		if not nome in out:
			out.append(nome)
	return out


## Verbo → come si scrive: **una frase** se non porta un numero, **due** —
## singolare e plurale — se lo porta. Aggiungere un verbo resta una riga (o due,
## se si conta); a dire se la quantità si mostra è la voce stessa, non un flag
## accanto che qualcuno dimenticherà di girare.
##
## Due frasi intere e non `"%d cart%s"`: quel `%s` porta una desinenza italiana,
## cioè mezza parola, che in nessun'altra lingua esiste e che nessun catalogo può
## contenere. Due frasi sono due chiavi che un traduttore sa leggere.
const VERBI := {
	"burn": ["Brucia %d carta avversaria in campo",
		"Brucia %d carte avversarie in campo"],
	"steal": ["Ruba la carta avversaria più vicina a partire"],
	"mill": ["Fa scartare %d carta dal mazzo avversario",
		"Fa scartare %d carte dal mazzo avversario"],
	"recover": ["Recupera %d carta dai tuoi scarti",
		"Recupera %d carte dai tuoi scarti"],
	"recycle": ["Torna nel mazzo invece di finire negli scarti"],
	"slow": ["Allunga di %d secondo l'attesa avversaria",
		"Allunga di %d secondi l'attesa avversaria"],
	"haste": ["Accorcia di %d secondo l'attesa delle tue altre carte",
		"Accorcia di %d secondi l'attesa delle tue altre carte"],
	"paralyze": ["Paralizza per %d secondo",
		"Paralizza per %d secondi"],
	"value_debuff": ["Toglie %d punto al valore delle carte avversarie in campo",
		"Toglie %d punti al valore delle carte avversarie in campo"],
	"slot_buff": ["Potenzia lo slot"],
	"match_buff": ["Potenzia le tue carte fino a fine battaglia"],
	"cleanse": ["Ti lava via veleno e sanguinamento"],
	"combo": ["Allunga la catena di %d anello",
		"Allunga la catena di %d anelli"],
	"combo_reset": ["Spegne la catena"],
}


## Come funzionano davvero le cose che **questa** carta fa. I numeri arrivano da
## `tuning.json`: girare una manopola non deve lasciare in giro una spiegazione
## che dice un'altra cosa.
func _glossario(card: Card, line: Dictionary) -> Array:
	var out: Array = []
	var utility: Dictionary = line.get("utility", {})

	if float(line.get("poison", 0.0)) != 0.0:
		out.append(["Veleno", tr("Toglie il suo numero di vita ogni %.0f secondi e **non cala mai**: "
			+ "resta fino a fine battaglia, o finché qualcosa non te lo lava via. "
			+ "Non passa dallo scudo. Al massimo %d per lato.")
			% [Cfg.get_float("battle.poison_every", 3.0), Cfg.get_int("battle.poison_cap", 5)]])

	if float(line.get("bleed", 0.0)) != 0.0:
		out.append(["Sanguinamento", tr("Toglie il suo numero di vita ogni secondo, e ogni volta "
			+ "il numero cala di uno: fa male subito e si spegne da solo. "
			+ "Non passa dallo scudo. Al massimo %d per lato.")
			% Cfg.get_int("battle.bleed_cap", 6)])

	if _buca_lo_scudo(card):
		out.append(["Colpo che buca", "Passa attraverso lo scudo e arriva dritto alla vita."])

	if utility.has("slot_buff"):
		out.append(["Buff di slot", "Potenzia il posto, non la carta: ne gode chiunque ci passi "
			+ "dopo. Uno solo per slot — quello nuovo cancella il vecchio."])
	if utility.has("match_buff"):
		out.append(["Fino a fine battaglia", "Vale per tutte le tue carte, comprese quelle che "
			+ "devono ancora entrare in campo."])
	if utility.has("paralyze"):
		out.append(["Paralisi", "Il tempo per quella carta si ferma: non avanza verso la sua "
			+ "attivazione finché non passa."])
	if utility.has("mill"):
		out.append(["Scartare dal mazzo", "Non uccide adesso: toglie carte alla pila avversaria, "
			+ "e il conto arriva quando dovrà rimpiazzarne una e non ne avrà più."])
	if utility.has("recover"):
		out.append(["Recuperare", "Riporta carte dagli scarti in fondo alla pila: si rigiocheranno, "
			+ "per ultime. È il modo di allontanare il momento in cui resti senza."])
	if utility.has("steal"):
		out.append(["Rubare", "Prende la carta avversaria più vicina a partire e si mette al suo "
			+ "posto. Lui dovrà pescarne un'altra: è un colpo alla plancia e al mazzo."])
	if utility.has("combo") or utility.has("combo_reset") or not card.combo_color.is_empty():
		out.append(["Catena", tr("Quando la carta che entra in uno slot ha lo stesso colore o lo "
			+ "stesso numero di quella appena uscita, la catena si allunga: da lì in poi "
			+ "**tutte** le tue carte colpiscono, curano e riparano il %d%% in più per anello. "
			+ "Non cala mai da sola.") % int(round(Cfg.get_float("battle.combo_step", 0.10) * 100.0))])

	if not card.evolves_to.is_empty():
		out.append(["Evoluzione", "Dopo essersi attivata cresce di livello e va negli scarti. "
			+ "La crescita **resta per il resto della partita**: dal round dopo nel mazzo c'è "
			+ "la creatura grande. Per rivederla in campo già in questa battaglia bisogna "
			+ "recuperarla dagli scarti."])
	if not card.tick_effects.is_empty():
		out.append(["Ogni secondo", "Questi numeri non arrivano all'attivazione: arrivano per "
			+ "ogni secondo che la carta passa ferma in plancia ad aspettare."])

	return out


## Se fra i suoi colpi ce n'è almeno uno che ignora lo scudo.
func _buca_lo_scudo(card: Card) -> bool:
	var trovato := [false]
	card.walk_effects(func(effect: Dictionary, _peso: float) -> void:
		if bool(effect.get("pierce", false)):
			trovato[0] = true
	)
	return trovato[0]


## Le caratteristiche che la carta produce stando ferma, siglate come sulla
## faccia: qui sono una riga sola e per esteso diventerebbero un paragrafo.
func _riga_tick(line: Dictionary) -> String:
	var tick: Dictionary = line.get("tick", {})
	if tick.is_empty():
		return ""
	var parti: Array[String] = []
	for key in Card.STAT_KEYS:
		var amount := int(roundf(float(tick.get(key, 0.0))))
		if amount != 0:
			parti.append("%d %s" % [amount, tr(String(NOME_STAT[key])).to_lower()])
	return " · ".join(parti)
