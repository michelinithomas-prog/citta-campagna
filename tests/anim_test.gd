extends TestCase
## Le animazioni di battaglia: `Gesti` e la parte animata di `CardView`.
##
## Un test headless non vede un pixel, e infatti non è quello che controlla. Qui
## si sorveglia l'unica cosa che, se salta, ferma la partita invece di fare una
## grafica brutta: **i nodi effimeri devono sempre morire**, i contatori devono
## sempre arrivare a zero, e nessuna animazione deve restare appesa a metà.
##
## Quello che resta fuori — che il bordo si veda sopra l'illustrazione, che il
## lampo sia leggibile, che il gesto non sia invadente — si guarda con gli
## occhi: `tools/foto_gesti.gd` fotografa una battaglia vera fotogramma per
## fotogramma, ed è lì che si vedono i bug di questa roba.

const FRAME := 1.0 / 60.0

var gesti: Gesti
var view: CardView


func before_each() -> void:
	gesti = Gesti.new()


func after_each() -> void:
	if gesti != null:
		gesti.free()
		gesti = null
	if view != null:
		view.free()
		view = null


func _rect() -> Rect2:
	return Rect2(Vector2(100, 200), CardView.SIZES[CardView.Mode.SLOT])


## Fa passare `quanti` sessantesimi di secondo.
func _avanza(quanti: int) -> void:
	for i in quanti:
		gesti.passo(FRAME)


# --- il fantasma ----------------------------------------------------------

func test_il_fantasma_nasce_e_muore() -> void:
	var carta := CardLibrary.build("picche_c5")
	assert_not_null(carta, "la carta di prova esiste")

	gesti.stoccata(_rect(), carta, -1)
	assert_eq(gesti.vivi(), 1, "il fantasma è nato")

	_avanza(Gesti.F_STOCCATA + 2)
	assert_eq(gesti.vivi(), 0, "il fantasma se n'è andato da solo")


func test_il_fantasma_si_allontana_nel_verso_giusto() -> void:
	var carta := CardLibrary.build("picche_c5")
	gesti.stoccata(_rect(), carta, -1)
	var nodo: Control = gesti.get_child(0)
	var partenza := nodo.position.y

	_avanza(Gesti.F_STOCCATA / 2)
	assert_true(nodo.position.y < partenza, "con verso −1 il fantasma sale")

	# E la posizione resta su pixel interi: con il filtro NEAREST mezzo pixel
	# fa tremolare il disegno.
	assert_eq(nodo.position.y, roundf(nodo.position.y), "posizione intera")


func test_niente_gesto_su_un_rettangolo_vuoto() -> void:
	# Capita davvero: uno slot chiesto prima che la schermata sia stata
	# disposta ha rettangolo a zero, e un fantasma là in mezzo sarebbe un
	# rettangolo beige nell'angolo dello schermo.
	gesti.stoccata(Rect2(), CardLibrary.build("picche_c5"), -1)
	assert_eq(gesti.vivi(), 0, "nessun gesto senza un posto dove metterlo")


# --- i numeri --------------------------------------------------------------

func test_due_colpi_di_seguito_sommano_invece_di_sovrapporsi() -> void:
	gesti.numero(-3, Hud.DANNO, _rect(), -1)
	gesti.numero(-4, Hud.DANNO, _rect(), -1)
	assert_eq(gesti.vivi(), 1, "un numero solo, non due")

	var etichetta: Label = gesti.get_child(0)
	assert_eq(etichetta.text, "-7", "i due colpi si sono sommati")


func test_colori_diversi_non_si_sommano_e_si_impilano() -> void:
	gesti.numero(-3, Hud.DANNO, _rect(), -1)
	gesti.numero(2, Hud.SCUDO, _rect(), -1)
	assert_eq(gesti.vivi(), 2, "danno e scudo restano due numeri")

	var primo: Label = gesti.get_child(0)
	var secondo: Label = gesti.get_child(1)
	assert_ne(primo.position.y, secondo.position.y, "il secondo parte da un'altra riga")


func test_il_numero_zero_non_esiste() -> void:
	gesti.numero(0, Hud.DANNO, _rect(), -1)
	assert_eq(gesti.vivi(), 0, "un colpo da zero non è successo")


func test_il_numero_se_ne_va_da_solo() -> void:
	gesti.numero(-5, Hud.DANNO, _rect(), -1)
	_avanza(Gesti.F_NUMERO + 2)
	assert_eq(gesti.vivi(), 0, "nessun numero resta appeso")


func test_svuota_porta_via_tutto() -> void:
	gesti.stoccata(_rect(), CardLibrary.build("picche_c5"), -1)
	gesti.numero(-5, Hud.DANNO, _rect(), -1)
	assert_gt(gesti.vivi(), 0, "c'era qualcosa da svuotare")

	gesti.svuota()
	assert_eq(gesti.vivi(), 0, "la lista è vuota")

	# `queue_free()` non libera subito: l'albero si ripulisce a fine frame, e
	# qui dentro un frame non passa mai. Quello che conta è che ogni nodo sia
	# stato messo in coda — nessuno resta orfano e vivo.
	for figlio in gesti.get_children():
		assert_true(figlio.is_queued_for_deletion(), "ogni nodo è in coda per morire")


# --- che verso prende il gesto ---------------------------------------------

func test_chi_colpisce_va_verso_l_avversario() -> void:
	# Le Picche fanno danno: dal lato del giocatore (casa = +1) il gesto deve
	# andare in su, cioè −1.
	var picche := CardLibrary.build("picche_c5")
	assert_eq(Gesti.verso_di(picche, 1), -1, "il colpo va verso il nemico")
	assert_eq(Gesti.tinta_di(picche), Hud.DANNO, "ed è rosso")


func test_chi_cura_torna_verso_casa() -> void:
	var cuori := CardLibrary.build("cuori_c5")
	assert_eq(Gesti.voce_dominante(cuori), "heal", "il Cinque di Cuori cura")
	assert_eq(Gesti.verso_di(cuori, 1), 1, "la cura va verso di sé")
	assert_eq(Gesti.tinta_di(cuori), Hud.CURA, "ed è verde")


func test_una_carta_senza_caratteristiche_e_ottone() -> void:
	# Non ha né danno né cura né scudo: non è un colpo, ma va segnalata lo
	# stesso, o le carte di sola utilità sparirebbero dal racconto.
	assert_eq(Gesti.tinta_di(null), Hud.OTTONE, "senza carta, ottone")


# --- la carta a schermo ----------------------------------------------------

func test_la_cornice_dell_evento_si_spegne_da_sola() -> void:
	view = CardView.new(CardLibrary.build("picche_c5"), false, CardView.Mode.SLOT)
	view.lampeggia(Hud.DANNO)
	assert_gt(view._cornice.modulate.a, 0.5, "la cornice è accesa")

	for i in CardView.F_EVENTO + 2:
		view.refresh(FRAME)
	assert_almost(view._cornice.modulate.a, 0.0, 0.001, "e si è spenta")


func test_l_ingresso_finisce_sempre_a_posto() -> void:
	view = CardView.new(CardLibrary.build("picche_c5"), false, CardView.Mode.SLOT)
	view.entra(1)
	assert_ne(view.position.y, 0.0, "la carta parte spostata")

	for i in CardView.F_INGRESSO + 2:
		view.refresh(FRAME)
	assert_almost(view.position.y, 0.0, 0.001, "torna al suo posto")
	assert_almost(view.modulate.a, 1.0, 0.001, "e torna opaca")


func test_concludi_taglia_di_netto() -> void:
	# È il caso di fine partita: da lì in poi nessuno chiama più `refresh`, e
	# una carta lasciata a metà ingresso resterebbe storta e sbiadita
	# sull'ultima schermata — quella che si guarda più a lungo di tutte.
	view = CardView.new(CardLibrary.build("picche_c5"), false, CardView.Mode.SLOT)
	view.entra(1)
	view.lampeggia(Hud.DANNO)

	view.concludi()
	assert_almost(view.position.y, 0.0, 0.001, "a posto")
	assert_almost(view.modulate.a, 1.0, 0.001, "opaca")
	assert_almost(view._cornice.modulate.a, 0.0, 0.001, "senza cornice")


func test_uno_slot_vuoto_resta_sbiadito_ma_non_sparisce() -> void:
	# L'alpha di riposo di uno slot vuoto è 0.25, ed è metà del racconto del
	# deck-out: se l'ingresso la moltiplicasse via, la sconfitta per
	# esaurimento non si vedrebbe arrivare.
	view = CardView.new(CardLibrary.build("picche_c5"), false, CardView.Mode.SLOT)
	view.entra(1)
	view.set_card(null)
	for i in CardView.F_INGRESSO + 2:
		view.refresh(FRAME)
	assert_almost(view.modulate.a, 0.25, 0.001, "sbiadito, non invisibile")


func test_refresh_senza_carta_non_esplode() -> void:
	view = CardView.new(null, false, CardView.Mode.SLOT)
	view.refresh(FRAME)
	view.refresh(0.0)
	assert_null(view.card, "e la carta resta nulla")
