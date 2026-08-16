class_name CardView
extends PanelContainer
## Una carta a schermo: seme, valore, cosa fa e quanto manca.
##
## Due velocità diverse, tenute separate apposta:
##   set_card()  cambia identità — succede due volte al secondo, ricostruisce i testi
##   refresh()   muove solo la barra — succede sessanta volte al secondo
##
## Per questo lo StyleBoxFlat si crea una volta sola in _init e poi si muta:
## rifarlo dentro refresh() significherebbe seicento allocazioni al secondo con
## dieci carte in campo.
##
## Quello che **non** sta qui sopra: nome per esteso, effetti uno per uno,
## spiegazione degli innesti. Su 120 px di larghezza coprivano il disegno e si
## spezzavano a metà parola. Stanno in `CardDetail`, che si apre passandoci sopra
## il mouse — di qui i segnali `hovered`/`unhovered`.

signal clicked(card: Card)
## Il mouse è entrato/uscito. Chi ascolta (`play.gd`) apre la scheda della carta:
## il `CardView` non se ne occupa perché la scheda è **una sola** per schermata,
## e non una per carta.
signal hovered(view: CardView)
signal unhovered(view: CardView)

enum Mode {
	SLOT,     ## in battaglia: barra del cooldown viva
	SHOP,     ## in vetrina: più alta, c'è spazio per il prezzo sotto
	COMPACT,  ## nel mazzo: venti carte devono starci tutte
}

## Gli sprite delle carte sono 240×330: queste misure sono sue frazioni esatte
## (½ e ¼), così il disegno non viene mai deformato né scalato a metà pixel.
const SIZES := {
	Mode.SLOT: Vector2(120, 165),
	Mode.SHOP: Vector2(120, 165),
	## Il mazzo può arrivare a trentadue carte e devono starcene dodici per riga
	## sotto la vetrina: da qui in giù non si scende senza renderle illeggibili.
	Mode.COMPACT: Vector2(60, 82),
}

## I nomi dei colori scritti nei JSON dei semi. Palette non ha una lookup per
## nome e non è il caso di aggiungergliela per un template solo.
const COLORS := {
	"danger": Palette.DANGER,
	"success": Palette.SUCCESS,
	"info": Palette.INFO,
	"gold": Palette.GOLD,
	"accent": Palette.ACCENT,
	"warning": Palette.WARNING,
	"secondary": Palette.SECONDARY,
}

var card: Card
var clickable := false
var mode: Mode = Mode.SLOT

## Quanto dura l'ingresso di una carta nuova e di quanto sale, e quanto resta
## accesa la cornice dell'evento. In frame da 1/60 e in pixel interi, come tutto
## il resto delle animazioni: vedi `gesti.gd`.
const F_INGRESSO := 8
const PX_INGRESSO := 9
const F_EVENTO := 16

var _face: Label
var _name: Label
var _effect: Label
var _seals: Label
var _timer: ProgressBar
var _style: StyleBoxFlat
## Il riempimento della barra del cooldown. Si **muta**, non si sostituisce, e
## soprattutto non si tinge con `modulate`: `modulate` moltiplica, e su una
## barra che nasce color accento darebbe un verde oliva invece del colore del
## seme. Tinge anche il fondo scuro della barra, che deve restare scuro.
var _riempimento: StyleBoxFlat
## La cornice degli eventi, e l'unica che si vede davvero su una carta
## illustrata: il bordo di `_style` sta sul PanelContainer, e `_art` è un figlio
## disegnato **dopo**, che lo copre. Questo Panel è l'ultimo figlio, non disegna
## il centro, e sta sopra il disegno.
var _cornice: Panel
var _cornice_stile: StyleBoxFlat
## Il disegno della carta, quando ne esiste uno. Se c'è, seme e nome non si
## scrivono più: sono già dentro l'illustrazione.
var _art: TextureRect
## La riga in fondo, dove stanno effetto e innesti. Nel mazzo non c'è: venti
## carte da 60 px non hanno spazio per scriverci niente.
var _fascia: Control
## Vero quando questa carta ha un'illustrazione. Decide se serve una cornice: su
## un disegno no, su un rettangolo di testo sì, o non si capisce dove finisce.
var _illustrata := false
var _sotto_il_mouse := false

## Lo stato delle due animazioni della carta, in frame che scendono. Sono float
## e non nodi: muoiono con la vista, e nessuna lambda le tiene in vita.
var _ingresso := 0.0
var _evento := 0.0
var _evento_colore := Hud.OTTONE
## Da dove entra una carta nuova: +1 se sale dal basso, −1 se scende dall'alto.
var _verso_casa := 1
## Vero solo per le carte in battaglia, che stanno dentro una cella e possono
## quindi essere spostate. Vedi `entra()`.
var _anima_posizione := false


## Un Label che sta nella carta e non la allarga mai.
##
## Il minimo è 1 e non 0 di proposito: a zero Godot non ha una larghezza su cui
## calcolare gli a capo e il testo sparisce del tutto. A 1 il Label non impone
## niente al contenitore — è la carta a dargli la sua larghezza — e l'autowrap
## lavora su quella. Senza questo, un nome lungo scritto in un font monospaziato
## allarga la carta e con lei l'intera fila, fino a farla uscire dallo schermo.
static func _incolonna(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Come sopra, ma per la fascia in fondo alla carta: **una riga sola, e se non
## ci sta si taglia**. Andare a capo lì sotto significa mangiarsi un terzo
## dell'illustrazione per scrivere "· +1", e a quel punto tanto vale leggerlo
## nella scheda, dove c'è scritto per esteso.
## Il contorno che tiene una scritta leggibile su qualunque disegno, senza
## doverle mettere un rettangolo dietro.
static func _contorna(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Hud.INCHIOSTRO)


static func _una_riga(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.custom_minimum_size.x = 1
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func color_of(name: String) -> Color:
	return COLORS.get(name, Palette.TEXT_DIM)


func _init(source: Card = null, can_click: bool = false, view_mode: Mode = Mode.SLOT) -> void:
	clickable = can_click
	mode = view_mode
	custom_minimum_size = SIZES[mode]
	# PASS, non IGNORE, anche quando la carta non si clicca: con IGNORE il mouse
	# non entra mai e in battaglia la scheda del dettaglio non si aprirebbe.
	mouse_filter = Control.MOUSE_FILTER_STOP if can_click else Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Nasce nuda: niente fondo, niente cornice, niente margini. Sotto c'è
	# l'illustrazione e deve arrivare fino al bordo — la cornice del tema le
	# mangiava sei pixel per lato, che su una carta del mazzo larga sessanta sono
	# un decimo del disegno. Fondo e cornice tornano in `set_card`, ma soltanto
	# per le carte che un disegno non ce l'hanno.
	_style = Hud.box(Color.TRANSPARENT)
	_style.content_margin_left = 0
	_style.content_margin_right = 0
	_style.content_margin_top = 0
	_style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", _style)

	var compact := mode == Mode.COMPACT

	_face = Ui.label("", 24 if compact else 34)
	_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Ogni riga di testo va tenuta al guinzaglio, altrimenti allarga la carta e
	# con lei tutta la fila: un Label senza a capo chiede la larghezza che gli
	# serve, e "Cinque di Denari" con un font monospaziato ne chiede più di
	# quanta la carta ne abbia. È così che la bottega finiva fuori dallo schermo.
	_name = Ui.dim("", Hud.TESTO_PICCOLO)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.visible = not compact
	_incolonna(_name)

	_effect = Ui.label("", Hud.TESTO_PICCOLO)
	_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_una_riga(_effect)

	# Gli innesti sono un rombo d'ottone per innesto, in coda all'effetto. Il loro
	# nome — "Affilato", "Pesante" — non ci sta accanto a "8 ATT · 2 SAN" senza
	# mandare la fascia a capo, e sta scritto per esteso nella scheda.
	_seals = Ui.label("", Hud.TESTO_PICCOLO, Hud.ORO)
	_seals.size_flags_horizontal = Control.SIZE_SHRINK_END

	_timer = Ui.bar(0.0, 1.0, Palette.ACCENT, 8)
	_timer.visible = mode == Mode.SLOT
	_riempimento = _timer.get_theme_stylebox("fill") as StyleBoxFlat

	# Il disegno sta sotto tutto: in un PanelContainer i figli si sovrappongono
	# riempiendo lo stesso spazio, e il primo aggiunto finisce in fondo.
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.visible = false
	add_child(_art)

	# Lo spacer sta in mezzo, non in fondo: spinge effetto, innesti e barra
	# nella parte bassa della carta. Su una carta illustrata è l'unico posto
	# dove si possono scrivere senza coprire il disegno.
	#
	# Qui sotto c'era una fascia nera che faceva da fondo alla scritta. Il
	# problema che risolveva è vero — le carte da gioco sono chiare, e testo
	# chiaro su fondo chiaro non si legge — ma la cura si vedeva più della
	# malattia: una riga nera in fondo a ogni carta, su dieci carte in campo.
	#
	# Adesso il testo si regge da solo, con un contorno abbastanza spesso da
	# staccarlo da qualunque sfondo. Non è il contorno del tema (quello è di un
	# pixel e su un disegno chiaro non basta): è il doppio, e del colore
	# dell'inchiostro.
	#
	# Nel mazzo la riga non c'è proprio: a sessanta pixel di larghezza qualsiasi
	# scritta è illeggibile, e il posto dove leggere la carta è la sua scheda.
	_contorna(_effect)
	_contorna(_seals)
	_fascia = Ui.hbox([_effect, _seals], 2)
	_fascia.visible = not compact

	# I testi di sopra hanno il loro margine; la fascia e la barra no, così
	# toccano i bordi della carta come in un mazzo vero.
	add_child(Ui.vbox([
		Ui.margin(Ui.vbox([_face, _name], 2), Palette.PAD_SMALL),
		Ui.spacer(), _fascia, _timer,
	], 0))

	# La cornice degli eventi, per ultima: in un PanelContainer i figli si
	# disegnano nell'ordine in cui sono aggiunti, e questa deve stare **sopra**
	# l'illustrazione. È il canale che dice "qui è appena successo qualcosa, ed
	# era di questo colore", e su nove carte su dieci il disegno c'è.
	#
	# `draw_center = false` non è un dettaglio: senza, il riquadro coprirebbe
	# tutta la carta invece di contornarla.
	_cornice_stile = Hud.box(Color.TRANSPARENT)
	_cornice_stile.draw_center = false
	_cornice_stile.set_border_width_all(0)
	_cornice = Panel.new()
	_cornice.add_theme_stylebox_override("panel", _cornice_stile)
	_cornice.modulate.a = 0.0
	add_child(_cornice)

	# Nessun figlio deve intercettare il mouse: se lo facesse, entrando nella
	# fascia il puntatore uscirebbe dalla carta e la scheda si chiuderebbe.
	_ignora_il_mouse(self)

	if source != null:
		set_card(source)


## Toglie il mouse a tutti i discendenti, ma non alla carta stessa.
static func _ignora_il_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignora_il_mouse(child)


## Cambia la carta mostrata. Da chiamare quando lo slot ne riceve una nuova,
## mai dentro _process.
func set_card(source: Card) -> void:
	card = source
	if card == null:
		_face.text = "—"
		_face.visible = true
		_name.text = ""
		_effect.text = ""
		_seals.text = ""
		_timer.value = 0.0
		_art.visible = false
		_illustrata = false
		_aggiorna_cornice()
		_applica_ingresso()
		return

	var tint := color_of(card.color_key)

	# Il disegno, se questa carta ce l'ha. Quando c'è, seme, valore e nome non si
	# scrivono più sopra: sono già disegnati dentro la carta, e riscriverli
	# significherebbe solo coprire l'illustrazione con roba doppia.
	var disegno := CarteArt.per_carta(card)
	_art.texture = disegno
	_art.visible = disegno != null
	_illustrata = disegno != null

	_face.visible = not _illustrata
	_name.visible = not _illustrata and mode != Mode.COMPACT

	# Il glifo del seme è un glifo e resta tale; la sigla si legge, e va tradotta
	# **qui**, sulla copia che finisce a schermo. Tradurla nel modello toglierebbe
	# l'illustrazione a mezzo mazzo senza un errore in console: `carte_art.gd`
	# compone da `card.short` il nome del file del poker (`card_K_S.png`) e di One
	# (`card_red_5.png`).
	_face.text = "%s %s" % [card.symbol, tr(card.short)]
	_face.add_theme_color_override("font_color", tint)
	_name.text = card.display_name
	# Nel mazzo questa fascia non si vede nemmeno: là le carte sono venti o più e
	# si riconoscono dal disegno, il resto si legge nella scheda del dettaglio.
	# `short_text()` e non `effect_text()`: con seme, valore e innesti che sommano
	# i loro effetti una carta ne ha quattro o cinque, e per esteso diventano un
	# paragrafo che spezza le parole a metà e fa le carte di altezze diverse.
	# La versione corta somma le caratteristiche e le sigla: "4 ATT · 1 SAN".
	_effect.text = card.short_text()
	_seals.text = "◈".repeat(card.seals.size())

	_riempimento.bg_color = tint
	_aggiorna_cornice()
	_applica_ingresso()


## Decide se questa carta ha una cornice, e di che colore.
##
## La regola è una sola: **la cornice serve solo quando manca il disegno.** Una
## carta illustrata ha già i suoi bordi stampati sopra, e ripassarli con una riga
## d'ottone toglie spazio all'immagine senza aggiungere niente — nel mazzo, dove
## le carte sono larghe sessanta pixel, ne toglie un decimo.
##
## Resta un caso in cui la riga la si vuole eccome: la carta che si può cliccare
## mentre ci passi sopra il mouse. Lì non è decorazione, è la risposta alla
## domanda "questa la posso scegliere?".
## Il bordo sta su `_cornice` e non su `_style`, e non è un capriccio: `_style`
## è lo stylebox del PanelContainer, e `_art` è un suo figlio disegnato dopo,
## che con i margini a zero lo copre per intero. Misurato: su una carta
## illustrata il pixel del bordo aveva il colore del disegno. Il bordo d'ottone
## dell'hover, in bottega, non si è mai visto per questo motivo.
##
## Da qui in poi la divisione è netta: **`_style` è il fondo, `_cornice` è il
## bordo.** Un proprietario per proprietà, o prima o poi due sistemi si
## contendono la stessa riga.
func _aggiorna_cornice() -> void:
	# Senza disegno la carta è un rettangolo di testo e ha bisogno di un fondo:
	# altrimenti non si capisce dove finisce una e comincia l'altra.
	_style.set_border_width_all(0)
	_style.bg_color = Color.TRANSPARENT if _illustrata else Hud.LEGNO
	_dipingi_cornice()


## Chi ha diritto alla cornice, adesso. Tre pretendenti, in ordine: l'evento che
## sta lampeggiando, il mouse su una carta che si può scegliere, e il bordo di
## famiglia che tiene insieme una carta senza disegno.
func _dipingi_cornice() -> void:
	if _evento > 0.0:
		_cornice_stile.set_border_width_all(Hud.BORDO)
		_cornice_stile.border_color = _evento_colore
		_cornice.modulate.a = clampf(_evento / float(F_EVENTO), 0.0, 1.0)
		return

	if clickable and _sotto_il_mouse:
		_cornice_stile.set_border_width_all(Hud.BORDO)
		_cornice_stile.border_color = Hud.OTTONE
		_cornice.modulate.a = 1.0
		return

	if _illustrata:
		_cornice.modulate.a = 0.0
		return

	# Il colore lo dichiara families.json — con quattro mazzi un ternario non
	# basta più.
	_cornice_stile.set_border_width_all(Hud.BORDO_SOTTILE)
	_cornice_stile.border_color = color_of(String(card.family_entry().get("color", "accent"))) \
		if card != null else Hud.OTTONE_SCURO
	_cornice.modulate.a = 1.0


func _on_mouse_entered() -> void:
	_sotto_il_mouse = true
	_aggiorna_cornice()
	if card != null:
		hovered.emit(self)


func _on_mouse_exited() -> void:
	_sotto_il_mouse = false
	_aggiorna_cornice()
	unhovered.emit(self)


## Sposta la barra, e fa scorrere le due animazioni della carta se ce n'è una in
## corso. Gira sessanta volte al secondo su dieci carte: sulla stragrande
## maggioranza dei frame esce dopo tre righe e **non alloca niente**.
##
## `delta` è opzionale perché fuori dalla battaglia — bottega, mazzo, scheda —
## nessuno anima niente e la barra basta.
## `anticipo` è il tempo simulato che il duello ha già accumulato ma non ancora
## consumato in un tick (`SimClock.resto()`). Serve a disegnare **dove sarà** la
## barra, non dove era: la simulazione avanza venti volte al secondo e lo schermo
## ne disegna cento e passa, quindi senza questa sottrazione la barra fa venti
## scatti al secondo mentre tutto il resto è fluido. La logica non se ne accorge.
func refresh(delta: float = 0.0, anticipo: float = 0.0) -> void:
	# La guardia sta qui e non in cima: la barra ha bisogno di una carta, le
	# animazioni no. Uno slot che si svuota nel deck-out deve poter finire la
	# sua dissolvenza, o resta congelato a metà — ed è metà del racconto della
	# sconfitta per esaurimento.
	if card != null:
		var total := card.interval()
		var atteso := maxf(card.cooldown - anticipo, 0.0)
		_timer.value = clampf(1.0 - atteso / maxf(total, 0.001), 0.0, 1.0)

	if _ingresso <= 0.0 and _evento <= 0.0:
		return

	var frames := delta * 60.0
	if _evento > 0.0:
		_evento = maxf(_evento - frames, 0.0)
		_dipingi_cornice()
	if _ingresso > 0.0:
		_ingresso = maxf(_ingresso - frames, 0.0)
		_applica_ingresso()


# --- animazioni ------------------------------------------------------------

## Una carta nuova è appena arrivata in questo slot: entra salendo dalla parte
## del proprio mazzo, cioè nella direzione opposta a quella in cui se n'è andata
## la precedente.
##
## Muove `position`, quindi **funziona solo se la vista sta dentro una cella**
## (un `Control` nudo) e non direttamente in un contenitore: un `HBoxContainer`
## riscrive posizione e scala dei figli a ogni riordino, e basta che una carta
## vicina cambi testo — o che si prema F5, che riassegna il tema — perché
## succeda. Ci pensa `play.gd::_fila_carte`.
func entra(verso_casa: int) -> void:
	_verso_casa = signi(verso_casa) if verso_casa != 0 else 1
	_anima_posizione = true
	_ingresso = float(F_INGRESSO)
	_applica_ingresso()


## Qui è appena successo qualcosa, ed era di questo colore.
func lampeggia(colore: Color) -> void:
	_evento_colore = colore
	_evento = float(F_EVENTO)
	_dipingi_cornice()


## Taglio netto: tutto a riposo, adesso. La chiama chi chiude la battaglia,
## perché da quel momento `_process` non fa più girare niente e una carta
## lasciata a metà ingresso resterebbe storta e sbiadita sull'ultima schermata —
## quella che il giocatore guarda più a lungo di tutte.
func concludi() -> void:
	_ingresso = 0.0
	_evento = 0.0
	position = Vector2.ZERO
	_applica_ingresso()
	_dipingi_cornice()


func _applica_ingresso() -> void:
	var u := 1.0 - clampf(_ingresso / float(F_INGRESSO), 0.0, 1.0)
	# `position` si tocca solo dopo che qualcuno ha chiesto un ingresso, cioè
	# solo in battaglia. In bottega e nel mazzo le carte stanno dentro un
	# contenitore: scriverci `position` le sposterebbe davvero, e ce le
	# lascerebbe finché nessuno riordina.
	if _anima_posizione:
		var scarto := PX_INGRESSO * float(_verso_casa) * pow(1.0 - u, 2.0)
		position = Vector2(0.0, roundf(scarto))
	# L'alpha di riposo di uno slot vuoto è 0.25: l'ingresso non deve
	# cancellarla, o lo slot vuoto tornerebbe opaco come uno pieno. A ingresso
	# finito `u` vale 1 e la moltiplicazione si annulla da sola: **è questa
	# l'unica riga che scrive `modulate.a`**, così due sistemi non se la
	# contendono.
	var riposo := 1.0 if card != null else 0.25
	modulate.a = riposo * lerpf(0.2, 1.0, u)


func _gui_input(event: InputEvent) -> void:
	if not clickable or card == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(card)
		accept_event()
