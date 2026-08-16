class_name SidePanel
extends VBoxContainer
## Lo stato di uno schieramento, disposto come nelle bozze: una barra della vita
## larga quanto tutta la fila di carte, e un riquadro d'informazioni di fianco.
##
## Il contatore delle carte non è un dettaglio decorativo: è la seconda barra
## della vita. Quando arriva a zero si perde, e il giocatore deve poterlo vedere
## avvicinarsi — per questo si accende di rosso quando resta poco.

## Il riquadro d'informazioni. Largo quanto serve a «56 carte in mazzo» su una
## riga sola: è il conteggio più lungo che il gioco possa produrre in italiano,
## e mandarlo a capo per due caratteri fa sembrare rotto un pannello che non lo è.
const LARGHEZZA_INFO := 186
## Lo spazio per il testo dentro il riquadro, tolti i margini. È un **minimo**,
## e serve a tenerlo fermo: senza, «9 carte in mazzo» stringeva il pannello di
## dieci pixel rispetto a «13 carte in mazzo», e il tavolo si spostava a ogni
## carta pescata.
const LARGHEZZA_TESTO := LARGHEZZA_INFO - Palette.PAD_SMALL * 2

var side: Side

## Gli stati che si leggono accanto alla barra, in quest'ordine. Per ciascuno:
## la sigla, il colore, e da dove si legge il numero.
##
## Sono tutti **di lato**, non di carta: la paralisi vive sui singoli slot ma
## quello che serve sapere a colpo d'occhio è quante carte sono ferme, non
## quale. Il dettaglio sta sulla carta.
# i18n
const STATI := [
	{"sigla": "VEL", "colore": Hud.VELENO},
	{"sigla": "SAN", "colore": Hud.SANGUE},
	{"sigla": "GELO", "colore": Hud.GELO},
	{"sigla": "CATENA", "colore": Hud.ORO},
	{"sigla": "BONUS", "colore": Hud.CURA},
]

var _hp_bar: ProgressBar
var _hp_text: Label
var _shield: Label
var _name: Label
var _pile: Label
var _discard: Label
var _info_style: StyleBoxFlat
## Un gettone per stato, nell'ordine di `STATI`. Nascono qui una volta sola e
## poi si accendono e si spengono: `refresh()` gira sessanta volte al secondo, e
## creare Label lì dentro significherebbe centinaia di nodi al secondo con due
## schieramenti in campo.
var _gettoni: Array[Label] = []


func _init(source: Side) -> void:
	side = source
	add_theme_constant_override("separation", Palette.PAD_SMALL)

	_costruisci_barra()
	_costruisci_info()
	refresh()


## La barra: vita a tutta larghezza, con il numero e lo scudo accanto.
func _costruisci_barra() -> void:
	_hp_bar = Ui.bar(side.hp, side.max_hp, Palette.SUCCESS, 22)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_hp_text = Ui.label("", Palette.FONT_BODY)
	_hp_text.custom_minimum_size.x = 92
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_shield = Ui.label("", Palette.FONT_BODY, Hud.SCUDO)
	_shield.custom_minimum_size.x = 60

	for stato in STATI:
		var gettone := Ui.label("", Palette.FONT_SMALL, stato["colore"])
		gettone.visible = false
		_gettoni.append(gettone)


## Il riquadro laterale: nome, carte rimaste, scarti.
func _costruisci_info() -> void:
	_name = Ui.label(side.display_name, Palette.FONT_HEADING)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_pile = Ui.label("", Palette.FONT_BODY)
	_pile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_discard = Ui.dim("", Palette.FONT_SMALL)
	_discard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_info_style = ThemeBuilder.box(
		Palette.SURFACE,
		Palette.ACCENT_DIM if side.is_player else Palette.ENEMY,
		Palette.RADIUS,
		Palette.BORDER_WIDTH
	)


## La riga della vita, da montare sopra o sotto la fila di carte.
func barra() -> PanelContainer:
	var pezzi: Array[Control] = [_hp_bar, _hp_text, _shield]
	pezzi.append_array(_gettoni)
	var riga := Ui.hbox(pezzi, Palette.PAD_SMALL)
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", ThemeBuilder.box(
		Palette.BG_DEEP, Palette.BORDER, Palette.RADIUS_SMALL, 1
	))
	pannello.add_child(Ui.margin(riga, Palette.PAD_SMALL))
	pannello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return pannello


## Il riquadro d'informazioni, da montare a lato.
func info() -> PanelContainer:
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _info_style)
	pannello.custom_minimum_size.x = LARGHEZZA_INFO
	# LARGHEZZA_INFO era un minimo e basta: le tre righe dentro potevano
	# spingerlo oltre, e con la lingua finta a +30% la battaglia sforava di
	# 36 px. Andare a capo lo rende anche un tetto.
	# L'andare a capo è la rete di sicurezza per una lingua più lunga
	# dell'italiano, non il comportamento normale: in italiano ci deve stare
	# tutto su una riga, e il minimo qui sotto è quello che glielo garantisce.
	# Il nome dell'avversario fa eccezione e a capo ci va davvero — «Il Vecchio
	# Contadino» su una riga sola vorrebbe un riquadro largo quasi il triplo.
	for riga: Label in [_name, _pile, _discard]:
		riga.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		riga.custom_minimum_size.x = LARGHEZZA_TESTO
	pannello.add_child(Ui.margin(Ui.vbox([
		_name, Ui.spacer(Palette.PAD_SMALL), _pile, _discard,
	], 2), Palette.PAD_SMALL))
	return pannello


func refresh() -> void:
	_hp_bar.max_value = side.max_hp
	_hp_bar.value = side.hp
	_hp_bar.modulate = Palette.gradient(side.hp_ratio())
	_hp_text.text = "%d / %d" % [side.hp, side.max_hp]

	var shield := side.shield()
	_shield.text = tr("◈ %d") % shield if shield > 0 else ""

	# Uno stato a zero non si scrive: una riga piena di zeri costringe a leggerla
	# tutta per scoprire che non c'è niente da leggere.
	_accendi(0, side.poison)
	_accendi(1, side.bleed)
	_accendi(2, _carte_ferme())
	_accendi(3, side.combo)
	_accendi(4, _bonus_di_partita())

	var rimaste := side.pile.remaining()
	# Due frasi intere, non "cart%s": quel %s portava una desinenza italiana,
	# e una desinenza non si traduce — la frase andrebbe rifatta da capo.
	_pile.text = Testo.plurale(rimaste,
		"%d carta in mazzo", "%d carte in mazzo") % rimaste
	# Sotto le tre carte il deck-out è dietro l'angolo: si accende.
	_pile.add_theme_color_override(
		"font_color", Palette.DANGER if rimaste <= 3 else Palette.TEXT
	)
	# «%d scartate» non diceva scartate *cosa*, e con una carta sola diceva
	# «1 scartate»: la parola torna nella frase, e le frasi diventano due.
	var scartate := side.pile.discarded()
	_discard.text = Testo.plurale(scartate,
		"%d carta scartata", "%d carte scartate") % scartate


## Accende il gettone con quel numero, o lo spegne se non c'è niente da dire.
func _accendi(indice: int, quanto: int) -> void:
	var gettone := _gettoni[indice]
	gettone.visible = quanto > 0
	if quanto > 0:
		# La sigla si vede a schermo, ma passa da un formato prima di arrivare
		# alla Label: lì la traduzione automatica non la incontra più.
		gettone.text = "%s %d" % [tr(String(STATI[indice]["sigla"])), quanto]


## Quante carte di questo schieramento sono ferme adesso. Non i secondi che
## restano: quelli cambiano venti volte al secondo e nessuno li legge.
func _carte_ferme() -> int:
	var quante := 0
	for slot in side.board_size:
		if side.board[slot] != null and side.paralysis[slot] > SimClock.EPSILON:
			quante += 1
	return quante


## Il bonus che vale fino a fine battaglia — il Re — sommato in un numero solo.
func _bonus_di_partita() -> int:
	var totale := 0.0
	for mod in side.match_mods:
		if String(mod.get("stat", "")) == "value" and int(mod.get("kind", -1)) == StatBlock.FLAT:
			totale += float(mod.get("value", 0.0))
	return int(roundf(totale))
