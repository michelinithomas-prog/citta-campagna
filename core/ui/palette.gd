class_name Palette
extends RefCounted
## Il punto unico da cui passa tutto l'aspetto del gioco.
##
## RITEMATIZZARE IL GIOCO IN JAM = cambiare i colori qui e premere F5.
## Non scrivere colori letterali altrove: passa sempre da queste costanti.

# --- superfici (dal più scuro al più chiaro) ----------------------------
const BG_DEEP := Color("#0f111a")      ## sfondo della finestra
const BG := Color("#171a26")           ## sfondo delle schermate
const SURFACE := Color("#212635")      ## pannelli, carte, slot
const SURFACE_HI := Color("#2c3346")   ## elemento sotto il mouse
const BORDER := Color("#3b4459")       ## bordi e separatori

# --- testo --------------------------------------------------------------
const TEXT := Color("#e9ecf5")         ## testo principale
const TEXT_DIM := Color("#98a0bb")     ## etichette, descrizioni
const TEXT_MUTED := Color("#5f6884")   ## disabilitato, suggerimenti

# --- identità -----------------------------------------------------------
const ACCENT := Color("#4ecdc4")       ## colore del gioco: azioni principali
const ACCENT_DIM := Color("#2b7a75")
const SECONDARY := Color("#9d6bff")    ## seconda voce: magia, speciali

# --- semantica ----------------------------------------------------------
const GOLD := Color("#f4c95d")         ## valuta
const DANGER := Color("#ef476f")       ## danno, perdita, errore
const SUCCESS := Color("#06d6a0")      ## cura, guadagno, conferma
const INFO := Color("#4d96ff")         ## scudo, difesa, neutro
const WARNING := Color("#ff9f45")

# --- rarità (shop, carte, unità) ---------------------------------------
const RARITY := {
	"common": Color("#98a0bb"),
	"uncommon": Color("#06d6a0"),
	"rare": Color("#4d96ff"),
	"epic": Color("#9d6bff"),
	"legendary": Color("#f4c95d"),
}

# --- squadre ------------------------------------------------------------
const ALLY := Color("#4ecdc4")
const ENEMY := Color("#ef476f")

# --- misure -------------------------------------------------------------
const RADIUS := 6
const RADIUS_SMALL := 3
const BORDER_WIDTH := 2
const PAD := 12
const PAD_SMALL := 6
const GAP := 8

# --- testo: dimensioni --------------------------------------------------
const FONT_TITLE := 40
const FONT_HEADING := 24
const FONT_BODY := 16
const FONT_SMALL := 13


## Colore della rarità, con fallback su "common".
static func rarity(name: String) -> Color:
	return RARITY.get(name, RARITY["common"])


## Colore per un valore che va da "male" a "bene" (barre della vita, punteggi).
static func gradient(ratio: float) -> Color:
	var t := clampf(ratio, 0.0, 1.0)
	if t < 0.5:
		return DANGER.lerp(WARNING, t * 2.0)
	return WARNING.lerp(SUCCESS, (t - 0.5) * 2.0)


## Variante trasparente, per sfondi e velature.
static func fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
