class_name Dialogo
extends Control
## Il fumetto: chi parla da una parte, quello che dice in un riquadro in basso.
##
## Sta **sopra** tutto il resto e si mangia i click: mentre parlano non si compra
## e non si combatte. Chiude da solo alla fine della scena, o subito con "Salta".
##
## Le battute arrivano da `game/data/dialoghi.json`, i volti da
## `game/data/personaggi.json`. Una battuta è una di queste cose:
##
##   {"chi": "gigi", "testo": "..."}   una battuta: targa col nome e ritratto
##   {"testo": "..."}                  una didascalia: nessun volto, testo smorto
##   {"capitolo": "..."}               un titolo in mezzo alla scena
##
## e in più, su qualsiasi battuta:
##
##   {"evidenzia": "vedi_mazzo"}       accende quel pezzo di schermata
##
## **L'evidenziazione è quello che lega il tutorial al gioco.** GiGi non spiega
## un'idea astratta: spiega il bottone che in quel momento è l'unica cosa
## illuminata sullo schermo. Il buco nel velo lo fa `_ritaglia`, e chi sa dove
## sta un pezzo di schermata è `play.gd` — vedi `trova_rettangolo`.

signal finito

## Quanto è grande un ritratto a schermo. I file sono quadrati (1254×1254): qui
## si scala a occhio, non a frazioni esatte, perché non sono pixel art da
## rispettare al pixel ma illustrazioni.
const RITRATTO := 300

## Caratteri al secondo della macchina da scrivere. Non è decorazione: dà il
## tempo di cominciare a leggere prima che la riga sia tutta lì, ed è quello che
## fa sembrare che qualcuno stia parlando invece che stampando.
const VELOCITA := 45.0

## Il riquadro del testo. Alto abbastanza per tre righe: le battute sono corte,
## ma le didascalie del copione sono periodi interi.
const ALTEZZA_TESTO := 150

## Quanto respira il ritaglio attorno alla cosa evidenziata.
const RESPIRO := 6

const VELO := 0.82

## Chi sa dove sta un pezzo di schermata. `play.gd` la riempie con una funzione
## che prende una chiave ("vedi_mazzo", "vetrina", "vita_mia") e restituisce il
## rettangolo di quel nodo, o un Rect2 vuoto se in questa schermata non c'è.
##
## È un Callable e non un riferimento ai nodi perché le schermate si
## ricostruiscono da capo di continuo: un nodo preso adesso, fra due battute,
## potrebbe essere già stato liberato.
var trova_rettangolo := Callable()

var _battute: Array = []
var _indice := -1
## Quanti caratteri sono già comparsi. Si conta in float perché avanza di
## `VELOCITA * delta` e a 45 caratteri al secondo un intero perderebbe il resto
## a ogni frame.
var _caratteri := 0.0
## Il buco nel velo, in coordinate di schermo. Vuoto = nessun buco.
var _buco := Rect2()
## Quale pezzo di schermata è acceso, per nome. Vuota = nessuno.
var _chiave := ""
## Vero quando il riquadro del testo è stato spostato in cima per non coprire la
## cosa evidenziata.
var _in_alto := false

var _veli: Array[ColorRect] = []
var _cornice_buco: Panel
var _riquadro: PanelContainer
var _sx: TextureRect
var _dx: TextureRect
var _targa: Label
var _testo: Label
var _avanti: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: finché parlano, i click sono suoi. Senza, si comprerebbe in una
	# bottega che sta sotto e non si vede.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 90

	# Il velo è fatto di quattro pezzi e non di uno: è così che si tiene un buco
	# in mezzo senza scomodare uno shader.
	for i in 4:
		var pezzo := ColorRect.new()
		pezzo.color = Hud.INCHIOSTRO
		pezzo.color.a = VELO
		pezzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_veli.append(pezzo)
		add_child(pezzo)

	_cornice_buco = Panel.new()
	_cornice_buco.add_theme_stylebox_override("panel",
		Hud.box(Color.TRANSPARENT, Hud.OTTONE, Hud.BORDO))
	_cornice_buco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cornice_buco.visible = false
	add_child(_cornice_buco)

	_sx = _crea_ritratto(false)
	_dx = _crea_ritratto(true)
	add_child(_sx)
	add_child(_dx)

	_riquadro = _crea_riquadro()
	add_child(_riquadro)

	# In alto a destra, dove non copre né i volti né il testo. Serve a chi
	# rigioca: il copione è lungo, e la seconda volta non lo si rilegge.
	var salta := Ui.button("Salta ▸", chiudi)
	salta.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	salta.position = Vector2(-120 - Hud.PAD, Hud.PAD)
	salta.custom_minimum_size = Vector2(120, 34)
	add_child(salta)


func _crea_ritratto(a_destra: bool) -> TextureRect:
	var ritratto := TextureRect.new()
	ritratto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ritratto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ritratto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ritratto.size = Vector2(RITRATTO, RITRATTO)
	ritratto.set_meta("a_destra", a_destra)
	return ritratto


func _crea_riquadro() -> PanelContainer:
	_targa = Ui.label("", Hud.TESTO_GRANDE, Hud.ORO)

	_testo = Ui.label("", Hud.TESTO)
	_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_testo.custom_minimum_size.x = 1
	_testo.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_avanti = Ui.dim("▼  clic o spazio", Hud.TESTO_PICCOLO)
	_avanti.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var colonna := Ui.vbox([_targa, _testo, _avanti], 2)
	colonna.custom_minimum_size.y = ALTEZZA_TESTO

	var riquadro := Hud.cornice(Ui.margin(colonna, Hud.PAD))
	riquadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return riquadro


# --- la scena ------------------------------------------------------------

## Comincia una scena. `scena` è una voce di `dialoghi.json`.
func mostra(scena: Dictionary) -> void:
	_battute = scena.get("battute", [])
	_indice = -1
	visible = true
	set_process(true)
	_avanza()


func chiudi() -> void:
	visible = false
	set_process(false)
	_battute = []
	_sx.texture = null
	_dx.texture = null
	_buco = Rect2()
	finito.emit()


## La battuta dopo. Se non ce ne sono più, la scena è finita.
func _avanza() -> void:
	_indice += 1
	if _indice >= _battute.size():
		chiudi()
		return

	var battuta: Dictionary = _battute[_indice]
	_caratteri = 0.0
	_ritaglia(String(battuta.get("evidenzia", "")))

	if battuta.has("capitolo"):
		_mostra_capitolo(String(battuta["capitolo"]))
	elif battuta.has("chi"):
		_mostra_battuta(String(battuta["chi"]), String(battuta.get("testo", "")))
	else:
		_mostra_didascalia(String(battuta.get("testo", "")))


## Accende un pezzo di schermata e spegne il resto. Chiave vuota (o pezzo che in
## questa schermata non esiste) = nessun buco, velo pieno come sempre.
##
## Qui si tiene solo la **chiave**: dov'è quel pezzo lo si richiede a ogni frame
## dentro `_disponi`. Chiederlo una volta sola non funziona — la lezione della
## bottega si apre nello stesso frame in cui la bottega viene costruita, e in
## quel momento i contenitori non hanno ancora dato una posizione a niente: il
## buco veniva ritagliato nell'angolo in alto a sinistra, su un pezzo di scaffale.
func _ritaglia(chiave: String) -> void:
	_chiave = chiave
	_misura_il_buco()


func _mostra_battuta(chi: String, testo: String) -> void:
	var voce := Content.entry("personaggi", chi) if Content.has("personaggi", chi) else {}

	# Il testo del sistema non è di nessuno: niente volti, niente targa, e sta
	# in mezzo come un cartello.
	if String(voce.get("stile", "")) == "sistema":
		_vesti(testo, "", HORIZONTAL_ALIGNMENT_CENTER, Hud.ORO)
		_sx.texture = null
		_dx.texture = null
		return

	_vesti(testo, String(voce.get("nome", chi.capitalize())), HORIZONTAL_ALIGNMENT_LEFT, Hud.CREMA)

	# Il ritratto va solo dalla sua parte, e l'altro lato si spegne: due volti
	# accesi insieme non fanno capire chi dei due sta parlando.
	var texture := _ritratto_di(voce)
	var a_destra := String(voce.get("lato", "destra")) == "destra"
	_dx.texture = texture if a_destra else null
	_sx.texture = null if a_destra else texture


func _mostra_didascalia(testo: String) -> void:
	_vesti(testo, "", HORIZONTAL_ALIGNMENT_CENTER, Hud.CREMA_DIM)
	_sx.texture = null
	_dx.texture = null


func _mostra_capitolo(titolo: String) -> void:
	_vesti(titolo, "", HORIZONTAL_ALIGNMENT_CENTER, Hud.OTTONE)
	_sx.texture = null
	_dx.texture = null


func _vesti(testo: String, nome: String, allineamento: int, colore: Color) -> void:
	_testo.text = testo
	_testo.horizontal_alignment = allineamento
	_testo.add_theme_color_override("font_color", colore)
	_testo.visible_characters = 0
	_targa.text = nome
	_targa.visible = nome != ""


func _ritratto_di(voce: Dictionary) -> Texture2D:
	var percorso := String(voce.get("ritratto", ""))
	if percorso == "" or not ResourceLoader.exists(percorso):
		return null
	return load(percorso)


# --- dove va ogni cosa ---------------------------------------------------

## Rimette a posto velo, riquadro e ritratti. Si rifà a ogni battuta e a ogni
## cambio di finestra: le posizioni dipendono dalla misura del viewport, e un
## calcolo fatto una volta sola sbaglia appena qualcuno ridimensiona.
## Dove sta adesso la cosa evidenziata, e di conseguenza dove va il riquadro del
## testo. Si rifà a ogni frame perché la risposta cambia: la schermata dietro si
## costruisce dopo, e i contenitori danno le posizioni un frame più tardi.
func _misura_il_buco() -> void:
	_buco = Rect2()
	if _chiave != "" and trova_rettangolo.is_valid():
		var trovato: Rect2 = trova_rettangolo.call(_chiave)
		if trovato.size.x > 1.0 and trovato.size.y > 1.0:
			_buco = trovato.grow(RESPIRO)

	_cornice_buco.visible = _buco.size.x > 0.0
	if _cornice_buco.visible:
		_cornice_buco.position = _buco.position
		_cornice_buco.size = _buco.size

	# Il riquadro del testo si sposta in cima quando quello che c'è da guardare
	# sta in basso: spiegare un bottone coprendolo è il modo migliore per non
	# farlo vedere.
	_in_alto = _cornice_buco.visible and _buco.get_center().y > get_viewport_rect().size.y * 0.55


func _disponi() -> void:
	_misura_il_buco()
	var schermo := get_viewport_rect().size
	var alto_riquadro := ALTEZZA_TESTO + Hud.PAD * 3

	# Il riquadro: in fondo di norma, in cima quando in fondo c'è da guardare.
	var y_riquadro: float = float(Hud.PAD) if _in_alto else schermo.y - alto_riquadro - Hud.PAD
	_riquadro.position = Vector2(Hud.PAD, y_riquadro)
	_riquadro.size = Vector2(schermo.x - Hud.PAD * 2, alto_riquadro)

	# I ritratti si appoggiano al riquadro dalla parte opposta al testo.
	for ritratto in [_sx, _dx]:
		var a_destra: bool = ritratto.get_meta("a_destra")
		ritratto.position = Vector2(
			schermo.x - RITRATTO - Hud.PAD if a_destra else Hud.PAD,
			y_riquadro + alto_riquadro + Hud.PAD if _in_alto else y_riquadro - RITRATTO
		)

	_stendi_il_velo(schermo)


## I quattro pezzi di velo attorno al buco. Con il buco vuoto il pezzo di sotto
## copre tutto da solo e gli altri tre restano di misura zero: è il caso normale,
## e non ha bisogno di un ramo suo.
func _stendi_il_velo(schermo: Vector2) -> void:
	var su := maxf(_buco.position.y, 0.0)
	var giu := minf(_buco.end.y, schermo.y) if _buco.size.y > 0.0 else 0.0
	_veli[0].position = Vector2.ZERO
	_veli[0].size = Vector2(schermo.x, su)
	_veli[1].position = Vector2(0.0, giu)
	_veli[1].size = Vector2(schermo.x, maxf(schermo.y - giu, 0.0))
	_veli[2].position = Vector2(0.0, su)
	_veli[2].size = Vector2(maxf(_buco.position.x, 0.0), maxf(giu - su, 0.0))
	_veli[3].position = Vector2(_buco.end.x, su)
	_veli[3].size = Vector2(maxf(schermo.x - _buco.end.x, 0.0), maxf(giu - su, 0.0))


# --- la macchina da scrivere ---------------------------------------------

func _process(delta: float) -> void:
	# Le posizioni si rifanno a ogni frame: costano quattro assegnazioni, e in
	# cambio la finestra si può ridimensionare mentre GiGi parla senza che il
	# buco resti dov'era.
	_disponi()
	if _finita_di_scrivere():
		return
	_caratteri += VELOCITA * delta
	_testo.visible_characters = int(_caratteri)


func _finita_di_scrivere() -> bool:
	# `get_total_character_count()` e non `text.length()`: il primo conta i
	# caratteri di quello che si VEDE, il secondo quelli della stringa
	# sorgente. Con una traduzione piu' lunga la macchina da scrivere si
	# fermerebbe prima della fine della battuta; con una piu' corta il clic
	# per saltarla non risponderebbe piu'.
	return (_testo.visible_characters < 0
		or _testo.visible_characters >= _testo.get_total_character_count())


## Un clic solo fa due cose diverse: se sta ancora scrivendo, finisce la riga;
## se la riga è finita, passa alla prossima. È la convenzione di ogni gioco che
## abbia mai avuto un dialogo, e chi gioca la conosce già.
func _tocca() -> void:
	if _finita_di_scrivere():
		_avanza()
		return
	_testo.visible_characters = -1
	_caratteri = float(_testo.get_total_character_count())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tocca()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_tocca()
			get_viewport().set_input_as_handled()
