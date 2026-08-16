class_name Hud
extends RefCounted
## Il vestito del gioco: colori, misure e cornici in stile legno e panno.
##
## Sta qui e non in `core/ui/palette.gd` per una ragione precisa: `core/` è
## symlinkato in tutti e cinque i template, e ritingere lì ritingerebbe anche
## deckbuilder, autobattler, idle e towerdefense. Questo file vale per Città &
## Campagna e basta.
##
## Due cose che sembrano dettagli e non lo sono:
##
##   - `anti_aliasing = false` su ogni StyleBox. È acceso di default, e senza
##     spegnerlo i bordi restano sfumati anche con gli angoli a raggio zero:
##     tutto continuerebbe a *non* sembrare pixel art, senza che si capisca il
##     perché.
##   - Gli angoli sono vivi ovunque (`RAGGIO = 0`). Il pixel art non ha curve.

# --- legno ---------------------------------------------------------------
const LEGNO_SCURO := Color("#241a12")   ## fondo della schermata
const LEGNO := Color("#3a2a1e")         ## pannelli
const LEGNO_CHIARO := Color("#4d3826")  ## rilievi, bottone sotto il dito

# --- panno ---------------------------------------------------------------
const PANNO := Color("#1f4032")         ## il tavolo, dove stanno le carte
const PANNO_CHIARO := Color("#2a5442")

# --- ottone --------------------------------------------------------------
const OTTONE := Color("#c9a227")        ## bordi accesi, oro, cose importanti
const OTTONE_SCURO := Color("#7a5c2e")  ## bordi a riposo

# --- testo ---------------------------------------------------------------
const CREMA := Color("#f2e5c8")
const CREMA_DIM := Color("#b9a480")
const CREMA_MUTED := Color("#7d6d52")
const INCHIOSTRO := Color("#140d08")    ## contorno del testo, ombre

# --- semantica -----------------------------------------------------------
## Scelti per restare leggibili sul legno *e* sopra un'illustrazione. La cura è
## volutamente più chiara del panno: su un tavolo verde un verde medio sparisce.
const DANNO := Color("#c8453a")
const CURA := Color("#8fd46a")
const SCUDO := Color("#5a8fc7")
const ORO := Color("#e8c04b")

## Gli stati alterati. Il veleno non è verde come la cura, per quanto sia il
## colore classico: in questo gioco il verde vuol dire "ti sta facendo bene", e
## due cose opposte con lo stesso colore si leggono male proprio nel momento in
## cui bisogna leggerle in fretta.
const VELENO := Color("#9b6bd6")   ## viola
const SANGUE := Color("#8c2f2a")   ## rosso scuro, più cupo di DANNO
const GELO := Color("#7fd8e8")     ## azzurro: le carte ferme

## Il colore dei semi neri. **Non** è nero: su un tavolo scuro un titolo nero
## non si legge, e l'informazione che deve passare non è "è di questa tinta" ma
## "non è rosso". Un grigio freddo lo dice e resta leggibile.
const NERO_CARTA := Color("#98a0b5")

# --- misure --------------------------------------------------------------
const RAGGIO := 0                       ## il pixel art non ha angoli tondi
const BORDO := 2
const BORDO_SOTTILE := 1
const PAD := 12
const PAD_SMALL := 6
const GAP := 8
## Lo stacco fra le due righe della cornice doppia.
const INTERCAPEDINE := 3

# --- testo ---------------------------------------------------------------
## Departure Mono è disegnato su una griglia da 11 px: le dimensioni nitide sono
## i suoi multipli. Fuori da questi le aste vengono di spessore diverso e il
## testo sembra sporco senza che si capisca perché.
const TESTO_TITOLO := 44
const TESTO_TITOLONE := 33
const TESTO_GRANDE := 22
const TESTO := 16
const TESTO_PICCOLO := 11

const FONT_TESTO := "res://game/fonts/DepartureMono-Regular.otf"
## Departure Mono non ha i semi romagnoli (● ◼ ◆) né lo scudo (◈): questi glifi
## arrivano da un ritaglio di GNU Unifont, 1,6 KB invece di cinque mega.
## Quando i semi diventeranno immagini pixel art, questo servirà solo per ◈.
const FONT_SIMBOLI := "res://game/fonts/simboli-unifont.otf"


## Una cornice piena, angoli vivi, niente sfumature.
static func box(fill: Color, bordo: Color = Color.TRANSPARENT, spessore: int = 0) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = fill
	stile.set_corner_radius_all(RAGGIO)
	# Acceso di default: senza spegnerlo i bordi restano morbidi e il pixel art
	# non si vede. È la prima cosa da controllare se "non sembra pixel".
	stile.anti_aliasing = false
	if spessore > 0:
		stile.set_border_width_all(spessore)
		stile.border_color = bordo
	stile.content_margin_left = PAD_SMALL
	stile.content_margin_right = PAD_SMALL
	stile.content_margin_top = PAD_SMALL
	stile.content_margin_bottom = PAD_SMALL
	return stile


## Un pannello semplice: una riga sola di bordo.
static func pannello(child: Control, fill: Color = LEGNO, bordo: Color = OTTONE_SCURO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(fill, bordo, BORDO))
	if child != null:
		p.add_child(child)
	return p


## La cornice a doppia linea dei menù a 16 bit: due riquadri annidati con un
## filo di stacco in mezzo.
##
## Costa due nodi invece di uno, quindi si usa sui pannelli grandi e **non sulle
## carte**: sono larghe 122 px, e sei pixel di cornice in più su dieci carte in
## campo si mangiano lo spazio che serve a leggere cosa fanno.
static func cornice(child: Control, fill: Color = LEGNO, bordo: Color = OTTONE) -> PanelContainer:
	var interno := PanelContainer.new()
	interno.add_theme_stylebox_override("panel", box(fill, bordo, BORDO_SOTTILE))
	if child != null:
		interno.add_child(child)

	var esterno := PanelContainer.new()
	esterno.add_theme_stylebox_override("panel", _box_esterno())
	esterno.add_child(interno)
	return esterno


static func _box_esterno() -> StyleBoxFlat:
	var stile := box(Color.TRANSPARENT, OTTONE_SCURO, BORDO)
	stile.content_margin_left = INTERCAPEDINE
	stile.content_margin_right = INTERCAPEDINE
	stile.content_margin_top = INTERCAPEDINE
	stile.content_margin_bottom = INTERCAPEDINE
	return stile


## Una barra: fondo scuro incassato, riempimento pieno, nessuna curva.
static func barra(valore: float, massimo: float, colore: Color, altezza: int = 16) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxf(massimo, 0.001)
	b.value = valore
	b.show_percentage = false
	b.custom_minimum_size.y = altezza
	b.add_theme_stylebox_override("background", box(INCHIOSTRO, OTTONE_SCURO, BORDO_SOTTILE))
	b.add_theme_stylebox_override("fill", box(colore))
	return b


## Il font del testo, con il ritaglio dei simboli come riserva.
static func font() -> FontVariation:
	var principale := FontVariation.new()
	principale.base_font = load(FONT_TESTO)
	if ResourceLoader.exists(FONT_SIMBOLI):
		principale.fallbacks = [load(FONT_SIMBOLI)]
	return principale


## Il tema locale della scena. Non sostituisce quello del core: gli si sovrappone
## e definisce solo le voci che gli interessano, il resto continua ad arrivare da
## `Ui.apply_theme()`. Sopravvive a F5, che riassegna soltanto `root.theme`.
##
## Serve per due cose che i costruttori `Ui.*` non sovrascrivono mai, e che
## quindi si possono ancora governare da qui: i **Button** (nessun override) e il
## **contorno del testo** — che è quello che tiene leggibili le scritte quando
## sotto ci sarà un'illustrazione invece del fondo pieno.
static func tema() -> Theme:
	var t := Theme.new()
	var f := font()
	t.default_font = f
	t.default_font_size = TESTO

	_stila_bottoni(t, f)
	_stila_testo(t, f)
	_stila_barre(t)
	return t


static func _stila_bottoni(t: Theme, f: Font) -> void:
	t.set_font("font", "Button", f)
	t.set_font_size("font_size", "Button", TESTO)
	t.set_stylebox("normal", "Button", box(LEGNO, OTTONE_SCURO, BORDO))
	t.set_stylebox("hover", "Button", box(LEGNO_CHIARO, OTTONE, BORDO))
	t.set_stylebox("pressed", "Button", box(OTTONE_SCURO, OTTONE, BORDO))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, OTTONE, BORDO))

	# Quasi opaco, non semitrasparente: da quando dietro c'è un'illustrazione e non
	# più un fondo pieno, un bottone spento al 60% lasciava passare la vetrina del
	# bar e la sua scritta spariva dentro i barattoli.
	var spento := box(LEGNO_SCURO, OTTONE_SCURO.darkened(0.3), BORDO)
	spento.bg_color.a = 0.92
	t.set_stylebox("disabled", "Button", spento)

	t.set_color("font_color", "Button", CREMA)
	t.set_color("font_hover_color", "Button", CREMA)
	t.set_color("font_pressed_color", "Button", INCHIOSTRO)
	t.set_color("font_disabled_color", "Button", CREMA_MUTED)
	t.set_color("font_outline_color", "Button", INCHIOSTRO)
	t.set_constant("outline_size", "Button", 1)


## Il contorno arriva a *ogni* Label del gioco senza toccare un solo call site:
## nessun costruttore di `Ui` sovrascrive `outline_size`. È l'accorgimento che
## costa meno e che regge di più quando sotto passerà un'illustrazione.
static func _stila_testo(t: Theme, f: Font) -> void:
	t.set_font("font", "Label", f)
	t.set_color("font_color", "Label", CREMA)
	t.set_color("font_outline_color", "Label", INCHIOSTRO)
	t.set_constant("outline_size", "Label", 1)
	# Il default è 3, pensato per un font vettoriale: su un font pixel spezza il
	# ritmo verticale e le righe sembrano scollegate.
	t.set_constant("line_spacing", "Label", 0)


static func _stila_barre(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar", box(INCHIOSTRO, OTTONE_SCURO, BORDO_SOTTILE))
	t.set_stylebox("fill", "ProgressBar", box(OTTONE))
	t.set_color("font_color", "ProgressBar", CREMA)
	t.set_font_size("font_size", "ProgressBar", TESTO_PICCOLO)
