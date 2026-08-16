class_name Gesti
extends Control
## Il regista delle animazioni di battaglia: tutto ciò che appare per un attimo
## e poi non c'è più nasce qui, vive qui e muore qui.
##
## ## Perché esiste
##
## In `duel.gd::_activate` succede tutto dentro lo stesso frame:
##
##     card_activated → resolve_all → take_from → discard → refill → slot_filled
##                                                                  → set_card(nuova)
##
## Sedici millisecondi dopo che una carta ha sparato, nel suo rettangolo c'è già
## un'altra faccia. **Il giocatore la carta che spara non la vede mai.** Da qui
## il fantasma: nell'istante dell'attivazione ne facciamo una copia leggera, la
## stacchiamo dal tavolo e la lasciamo andare, mentre sotto la carta nuova sale
## al suo posto. I due gesti si sovrappongono, e lo slot non ha mai un buco.
##
## ## Le cinque regole, tutte pagate con una sonda
##
## 1. **Ogni nodo che nasce qui è cieco al mouse.** I default di Godot non
##    aiutano: `ColorRect` e `PanelContainer` sono STOP, `TextureRect` è PASS, e
##    basta uno di loro sopra una carta perché la `CardView` sotto riceva
##    `mouse_exited` e la scheda del dettaglio cominci a sfarfallare. Tutto passa
##    da `_adotta()`, che non è un consiglio: è l'unica strada.
## 2. **Il lampo bianco non si fa con `modulate`.** `modulate` moltiplica: su
##    un'illustrazione vera diventa bianco pieno solo il 30-60% dei texel, i
##    contorni scuri restano scuri e si vede una carta sovraesposta, non una
##    sagoma. Si fa con un rettangolo pieno sopra — l'illustrazione è 240×330
##    dentro 120×165, esattamente metà, quindi riempie il rettangolo al pixel e
##    il rettangolo *è* la sagoma. Nessuno shader, nessun materiale per nodo.
## 3. **Niente `scale`, mai.** Vedi sopra: mezzo texel con filtro NEAREST non è
##    morbidezza, è tremolio. Tutti gli spostamenti sono interi.
## 4. **Il tempo si conta in frame da 1/60, non in frame di schermo.** Su un
##    monitor a 144 Hz una tabella letta a ogni frame durerebbe due volte e
##    mezzo di meno. Da qui l'accumulatore in `passo()`.
## 5. **I gesti avanzano solo quando avanza la simulazione.** `passo()` la chiama
##    `play.gd::_process`, accanto a `duel.advance()`: quando GiGi parla il
##    tavolo si ferma, e si fermano anche i gesti. Con dei Tween continuerebbero
##    a correre sotto il velo del dialogo.
##
## ## Perché non c'è un budget
##
## Contati sui segnali veri, seed 90210 e 4242: **1,1 attivazioni al secondo a
## 1×, 4,4-4,9 a 4×** — non le tre e le dodici che si stimano a mente, perché la
## briscola in mazzo porta la media dei cooldown vicino ai nove secondi. Con
## 0,25 s di vita per fantasma fa **poco più di un nodo effimero vivo alla
## volta**, picco quattro. Un budget con soglie e degradazione sarebbe codice
## che non gira mai, e codice che non gira mai è codice mai collaudato.

# --- il metronomo ---------------------------------------------------------

const FRAME := 1.0 / 60.0
## Dopo uno scatto non si recuperano venti frame in uno: si perde il tempo e
## basta. Quattro passi sono 66 ms, oltre i quali un gesto salta e va bene così.
const MAX_PASSI := 4

# --- durate, in frame da 1/60 ---------------------------------------------

const F_STOCCATA := 14   ## 0,23 s — la carta che ha sparato se ne va
const F_CONGEDO := 18    ## 0,30 s — bruciata, rubata, evoluta: più lento, è raro
const F_NUMERO := 30     ## 0,50 s — il numero deve restare leggibile
const F_LAMPO := 2       ## l'impatto: due frame e via

# --- ampiezze, in pixel interi --------------------------------------------

const PX_SPINTA := 26    ## quanto si allontana il fantasma
const PX_CADUTA := 18    ## quanto scende una carta bruciata
const PX_NUMERO := 30    ## quanto sale il numero

## Il numero è la cosa che dice **quanto**, ed è l'unica: deve battere
## l'illustrazione senza chiedere permesso. Da dieci in su cresce ancora.
##
## Le due misure sono multipli di undici perché è la griglia su cui è disegnato
## Departure Mono: fuori dai suoi multipli le aste vengono di spessore diverso e
## il numero sembra sporco senza che si capisca perché.
const CORPO_NUMERO := 33
const CORPO_NUMERO_GROSSO := 44
## Il doppio del contorno che tiene leggibile la scritta in fondo alla carta: il
## numero passa sopra illustrazioni chiare, scure e sopra il panno.
const CONTORNO_NUMERO := 8

enum Tipo { STOCCATA, CONGEDO, NUMERO }

## Il colore di ogni verbo. Le tre cose che tolgono vita sono tutte rosse: al
## giocatore serve sapere che sta perdendo, non con quale strumento.
const TINTE := {
	"damage": Hud.DANNO, "bleed": Hud.DANNO, "poison": Hud.DANNO,
	"heal": Hud.CURA, "shield": Hud.SCUDO, "gold": Hud.ORO,
}

## Le voci che rendono una carta "rivolta a sé": chi cura, chi para, chi incassa.
const VERSO_CASA := ["heal", "shield", "gold"]


## Cosa ha fatto questa carta, in un colore.
##
## Vince la caratteristica **positiva** più grossa, non quella in valore
## assoluto: una carta col danno netto negativo — le Picche che si feriscono da
## sole — lampeggerebbe rossa come se avesse colpito. A parità decide l'ordine
## di `Card.STAT_KEYS`. Se non c'è nessuna caratteristica la carta è di sola
## utilità (burn, recycle, catena) e il colore è l'ottone, che nel vestito di
## questo gioco vuol dire "una cosa importante, ma non un colpo".
static func voce_dominante(carta: Card) -> String:
	if carta == null:
		return ""
	var riga := carta.stat_line()
	var vincitrice := ""
	var massimo := 0
	for chiave in Card.STAT_KEYS:
		var valore := int(riga.get(chiave, 0))
		if valore > massimo:
			massimo = valore
			vincitrice = String(chiave)
	return vincitrice


static func tinta_di(carta: Card) -> Color:
	return TINTE.get(voce_dominante(carta), Hud.OTTONE)


## In che direzione mandare il gesto. `casa` è +1 per il lato in basso (il
## giocatore) e −1 per quello in alto: chi cura o si difende va verso casa, chi
## colpisce va verso l'avversario. È l'informazione che costa meno di tutte —
## nessun nodo, nessun pixel in più — e dice a chi era rivolta la carta.
static func verso_di(carta: Card, casa: int) -> int:
	return casa if voce_dominante(carta) in VERSO_CASA else -casa

var _vivi: Array[Dictionary] = []
var _accumulato := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- i gesti ---------------------------------------------------------------

## La carta ha sparato: si stacca dal tavolo e se ne va verso chi ha colpito.
##
## `verso` è −1 se il gesto va verso l'alto, +1 verso il basso: chi chiama sa
## da che parte sta il bersaglio, il regista no.
func stoccata(rect: Rect2, carta: Card, verso: int) -> void:
	if rect.size.x <= 0.0:
		return
	var nodo := _fantasma(rect, carta, Hud.CREMA)
	_vivi.append({
		"tipo": Tipo.STOCCATA, "nodo": nodo, "f": 0, "fine": F_STOCCATA,
		"base": rect.position, "verso": signi(verso),
	})


## La carta lascia lo slot per una ragione che non è l'attivazione. Un gesto
## solo, tre versioni: chi brucia cade, chi è rubata scivola dall'altra parte,
## chi evolve se ne va in gloria.
func congedo(rect: Rect2, carta: Card, motivo: String, verso: int) -> void:
	if rect.size.x <= 0.0:
		return
	var lampo := Hud.DANNO
	if motivo == Duel.MOTIVO_EVOLUTA:
		lampo = Hud.ORO
	elif motivo == Duel.MOTIVO_RUBATA:
		lampo = Hud.OTTONE
	var nodo := _fantasma(rect, carta, lampo)
	_vivi.append({
		"tipo": Tipo.CONGEDO, "nodo": nodo, "f": 0, "fine": F_CONGEDO,
		"base": rect.position, "verso": signi(verso), "motivo": motivo,
	})


## Il numero: quanto è costato davvero, dopo scudo e dopo catena.
##
## Nasce sul bordo della carta rivolto al bersaglio e sale in quella direzione.
## Un numero per colpo: se ne arriva un altro sulla stessa carta prima che il
## primo sia sparito, i due si **sommano** invece di sovrapporsi.
func numero(valore: int, colore: Color, rect: Rect2, verso: int) -> void:
	if valore == 0 or rect.size.x <= 0.0:
		return
	var v := signi(verso)

	for voce in _vivi:
		if voce["tipo"] != Tipo.NUMERO:
			continue
		if not is_instance_valid(voce["nodo"]):
			continue
		if voce["colore"] != colore or not voce["base"].is_equal_approx(rect.position):
			continue
		# Stessa carta, stesso tipo, ancora in volo: un numero solo che cresce.
		voce["valore"] = int(voce["valore"]) + valore
		voce["f"] = 0
		_scrivi_numero(voce)
		return

	var etichetta := Label.new()
	etichetta.add_theme_color_override("font_color", colore)
	etichetta.add_theme_color_override("font_outline_color", Hud.INCHIOSTRO)
	etichetta.add_theme_constant_override("outline_size", CONTORNO_NUMERO)
	etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etichetta.size = Vector2(rect.size.x, 0)
	_adotta(etichetta)

	var voce := {
		"tipo": Tipo.NUMERO, "nodo": etichetta, "f": 0, "fine": F_NUMERO,
		"base": rect.position, "verso": v, "valore": valore,
		"colore": colore, "misura": rect.size,
		# Una carta ne fa spesso due insieme — tre danni e due scudi — e i due
		# numeri hanno colori diversi, quindi non si sommano. Se nascessero nello
		# stesso punto si coprirebbero: il secondo parte una riga più avanti, e
		# si legge come una colonnina.
		"riga": _numeri_vivi_su(rect.position),
	}
	_scrivi_numero(voce)
	_vivi.append(voce)


## Tutto a riposo, subito. La chiama chi costruisce o smonta la battaglia: un
## gesto non deve mai sopravvivere alla schermata che l'ha generato.
func svuota() -> void:
	for voce in _vivi:
		if is_instance_valid(voce["nodo"]):
			(voce["nodo"] as Node).queue_free()
	_vivi.clear()
	_accumulato = 0.0


func vivi() -> int:
	return _vivi.size()


# --- il passo --------------------------------------------------------------

## Avanza i gesti di `delta` secondi reali, a passi fissi da 1/60.
func passo(delta: float) -> void:
	if _vivi.is_empty():
		_accumulato = 0.0
		return
	_accumulato += delta
	var fatti := 0
	while _accumulato >= FRAME and fatti < MAX_PASSI:
		_accumulato -= FRAME
		fatti += 1
		_un_frame()
	# Oltre il tetto il tempo arretrato si butta: recuperarlo farebbe scattare
	# tutti i gesti in avanti tutti insieme, che si vede più del salto.
	if _accumulato >= FRAME:
		_accumulato = 0.0


func _un_frame() -> void:
	for i in range(_vivi.size() - 1, -1, -1):
		var voce: Dictionary = _vivi[i]
		var nodo: Node = voce["nodo"]
		# La schermata di battaglia può essere stata ricostruita sotto di noi.
		if not is_instance_valid(nodo):
			_vivi.remove_at(i)
			continue

		voce["f"] = int(voce["f"]) + 1
		if int(voce["f"]) >= int(voce["fine"]):
			(nodo as Node).queue_free()
			_vivi.remove_at(i)
			continue

		match int(voce["tipo"]):
			Tipo.STOCCATA: _posa_stoccata(voce)
			Tipo.CONGEDO: _posa_congedo(voce)
			Tipo.NUMERO: _posa_numero(voce)


## Parte di scatto e rallenta, sbiadendo. Il lampo dura due frame: è l'impatto,
## non un'illuminazione.
func _posa_stoccata(voce: Dictionary) -> void:
	var nodo: Control = voce["nodo"]
	var u := float(voce["f"]) / float(voce["fine"])
	var fuori := PX_SPINTA * (1.0 - pow(1.0 - u, 3.0)) * float(voce["verso"])
	nodo.position = (voce["base"] as Vector2) + Vector2(0.0, roundf(fuori))
	nodo.modulate.a = clampf(1.0 - pow(u, 1.4), 0.0, 1.0)
	_spegni_lampo(voce)


## Il gesto rovesciato: chi se ne va senza aver sparato non parte, sussulta e
## cade all'indietro. Chi è rubata scivola invece verso chi se l'è presa.
func _posa_congedo(voce: Dictionary) -> void:
	var nodo: Control = voce["nodo"]
	var f := int(voce["f"])
	var u := float(f) / float(voce["fine"])
	var casa := -int(voce["verso"])
	var giu := PX_CADUTA * u * u * float(casa)
	var scarto := 0.0
	if String(voce["motivo"]) == Duel.MOTIVO_RUBATA:
		# Rubata: nessuna caduta, se ne va di lato dalla parte del ladro.
		giu = PX_SPINTA * (1.0 - pow(1.0 - u, 2.0)) * float(voce["verso"])
	elif String(voce["motivo"]) != Duel.MOTIVO_EVOLUTA:
		# Bruciata: tre frame di tremito, poi giù.
		scarto = roundf(sin(float(f) * 2.1) * 3.0 * maxf(1.0 - u * 3.0, 0.0))
	if String(voce["motivo"]) == Duel.MOTIVO_EVOLUTA:
		# Evoluta: sale, non cade. È un premio, e va letto come tale.
		giu = -PX_SPINTA * (1.0 - pow(1.0 - u, 2.0)) * float(casa)
	nodo.position = (voce["base"] as Vector2) + Vector2(scarto, roundf(giu))
	nodo.modulate.a = clampf(1.0 - pow(u, 1.6), 0.0, 1.0)
	_spegni_lampo(voce)


func _spegni_lampo(voce: Dictionary) -> void:
	var nodo: Control = voce["nodo"]
	if nodo.get_child_count() == 0:
		return
	var lampo := nodo.get_child(nodo.get_child_count() - 1) as CanvasItem
	if lampo == null:
		return
	lampo.modulate.a = clampf(1.0 - float(voce["f"]) / float(F_LAMPO), 0.0, 1.0) * 0.9


## Sale con la coda dell'occhio: decelera e sbiadisce solo nell'ultimo terzo,
## così il numero si legge per tutto il tempo in cui è grande.
func _posa_numero(voce: Dictionary) -> void:
	var nodo: Control = voce["nodo"]
	var u := float(voce["f"]) / float(voce["fine"])
	var su := PX_NUMERO * (1.0 - pow(1.0 - u, 2.0)) * float(voce["verso"])
	nodo.position = _origine_numero(voce) + Vector2(0.0, roundf(su))
	nodo.modulate.a = clampf((1.0 - u) / 0.34, 0.0, 1.0)


## Il numero nasce **sopra la carta**, non sopra il tavolo: dentro il suo
## rettangolo, a un terzo dal bordo verso cui viaggerà. Nascendo fuori finiva
## sulla riga del racconto in mezzo al campo e la copriva, e su un tavolo alto
## 648 pixel non c'è spazio per farlo partire da più lontano.
func _origine_numero(voce: Dictionary) -> Vector2:
	var misura: Vector2 = voce["misura"]
	var base: Vector2 = voce["base"]
	var corpo := float(_corpo(int(voce["valore"])))
	var alto := int(voce["verso"]) < 0
	var dentro := misura.y * 0.30 if alto else misura.y * 0.70 - corpo
	# Le righe si impilano nella direzione opposta al viaggio, così la prima
	# resta sempre davanti.
	var riga := float(int(voce.get("riga", 0))) * corpo * 0.85 * float(-int(voce["verso"]))
	return base + Vector2(0.0, roundf(dentro + riga))


func _numeri_vivi_su(base: Vector2) -> int:
	var quanti := 0
	for voce in _vivi:
		if int(voce["tipo"]) == Tipo.NUMERO and (voce["base"] as Vector2).is_equal_approx(base):
			quanti += 1
	return quanti


func _corpo(valore: int) -> int:
	return CORPO_NUMERO_GROSSO if absi(valore) >= 10 else CORPO_NUMERO


func _scrivi_numero(voce: Dictionary) -> void:
	var etichetta: Label = voce["nodo"]
	var valore := int(voce["valore"])
	etichetta.add_theme_font_size_override("font_size", _corpo(valore))
	etichetta.text = ("%d" % valore) if valore < 0 else ("+%d" % valore)
	etichetta.position = _origine_numero(voce)
	etichetta.modulate.a = 1.0


# --- la copia della carta --------------------------------------------------

## Una copia leggera della carta che sta lasciando lo slot, con sopra il lampo.
##
## Non è una `CardView`: sarebbe una dozzina di nodi per un oggetto che vive un
## quarto di secondo. È l'illustrazione e basta — e quando l'illustrazione non
## c'è, il rettangolo di legno con seme e valore, che è quello che la carta
## mostra davvero in quel caso.
func _fantasma(rect: Rect2, carta: Card, lampo: Color) -> Control:
	var corpo: Control
	var disegno := CarteArt.per_carta(carta) if carta != null else null

	if disegno != null:
		var immagine := TextureRect.new()
		immagine.texture = disegno
		immagine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		immagine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corpo = immagine
	else:
		var tinta := CardView.color_of(carta.color_key) if carta != null else Hud.OTTONE_SCURO
		var riquadro := PanelContainer.new()
		riquadro.add_theme_stylebox_override("panel", Hud.box(Hud.LEGNO, tinta, Hud.BORDO_SOTTILE))
		var faccia := Ui.label("%s %s" % [carta.symbol, carta.short] if carta != null else "—",
			Hud.TESTO_GRANDE, tinta)
		faccia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		faccia.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		riquadro.add_child(faccia)
		corpo = riquadro

	corpo.size = rect.size
	corpo.position = rect.position

	# Il lampo va aggiunto per ultimo — `_spegni_lampo` conta su questo — e
	# copre tutto il rettangolo, che è esattamente la sagoma della carta.
	var velo := ColorRect.new()
	velo.color = lampo
	velo.size = rect.size
	corpo.add_child(velo)

	_adotta(corpo)
	return corpo


# --- fondamenta ------------------------------------------------------------

## L'unica porta d'ingresso all'albero dei gesti, e il motivo per cui esiste:
## rendere cieco al mouse il nodo **e ogni suo discendente**. Un solo nodo che
## intercetta il puntatore fa sfarfallare la scheda del dettaglio, e non lascia
## un errore in console dietro di sé.
func _adotta(nodo: Control) -> void:
	nodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardView._ignora_il_mouse(nodo)
	add_child(nodo)
