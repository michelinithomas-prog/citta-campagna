class_name RunState
extends RefCounted
## Quello che il giocatore si porta dietro fra una battaglia e l'altra: il
## mazzo, l'oro, le vite, i bonus raccolti negli eventi.
##
## È la memoria della partita. Il Duel non la conosce e non la tocca: riceve
## copie delle carte, così una battaglia non lascia cicatrici sul mazzo vero.

signal changed

const GOLD := "gold"

var round_number := 1
## Le battaglie vinte. **È questo che chiude la partita**, non il numero di
## round: si vince facendo dieci vittorie prima di finire le vite, e una
## sconfitta non fa avanzare l'avversario — te lo fa ritrovare davanti.
var wins := 0
var lives := 2
## Quante vite sono state pagate finora. Non è `partenza - lives`: le reliquie
## regalano vite in corsa, e senza un contatore suo il conto tornerebbe sbagliato
## esattamente per chi ne ha comprata una.
var lives_lost := 0
var max_hp := 45
## Vera solo se l'ultimo round è stato vinto. Non si deduce dalle vite: si può
## arrivare in fondo con zero vite e aver vinto lo stesso.
var victory := false
var collection: Array[Card] = []
var wallet: Wallet
## Bonus validi per tutta la run, applicati a ogni carta che scende in campo:
## {"family"|"suit": id, "value_min"|"value_max": n, "value_add"|"value_mult"|"cooldown_scale": x}
var passives: Array = []
## Le reliquie comprate: oggetti che valgono per tutta la partita. Quelle che
## toccano le carte versano una regola in `passives`; le altre si leggono dai
## metodi qui sotto (vita, slot, oro, scudo, prezzi).
var relics: Array[Dictionary] = []

## Quello che vale **solo per la prossima battaglia** e poi si consuma: un
## temporale che ti lascia acciaccato, una scossa che ti fa partire paralizzato.
## Lo legge `play.gd` quando costruisce lo schieramento, e lo svuota subito dopo.
var next_battle: Dictionary = {}

## Vera se la run è stata chiusa da un evento invece che dalle vite. C'è una
## scelta che la finisce, ed è la scelta giusta.
var abandoned := false

## Le scene di dialogo già viste in questa partita. Si salva insieme al resto:
## chi riprende da "Continua" non deve rifarsi l'introduzione da capo.
var dialoghi_visti: Array[String] = []

## Vera finché la partita di prova contro GiGi non è stata giocata.
##
## Quella partita **non conta**: non fa avanzare le vittorie, non costa vite e
## non ti mette davanti Il Baro. Serve solo a imparare come si sta al tavolo, e
## si gioca col mazzo di sola briscola — le carte di città le regala GiGi subito
## dopo. È il primo avversario vero a essere la prima vittoria.
var tutorial := true

var _rng: RngStream


func _init(rng: RngStream = null) -> void:
	_rng = rng if rng != null else RngStream.new(1)
	lives = maxi(Cfg.get_int("player.lives", 2), 1)
	max_hp = maxi(Cfg.get_int("player.hp", 45), 1)
	wallet = Wallet.new({GOLD: float(Cfg.get_int("shop.starting_gold", 5))})
	collection = CardLibrary.deck_from_ids(Cfg.get_value("deck.starting", []))


## Una carta costruita adesso, coi bonus della run già addosso. La battaglia ne
## crea di sue — un Germoglio, un gaiofanamon dell'Antigh — e devono nascere
## uguali a quelle del mazzo, o le reliquie varrebbero solo per metà squadra.
func make_card(card_id: String) -> Card:
	var card := CardLibrary.build(card_id)
	if card != null:
		_apply_passives(card)
	return card


## Il mazzo che scende in campo: copie con i bonus della run già applicati.
func battle_deck() -> Array[Card]:
	var out: Array[Card] = []
	for i in collection.size():
		var copy := collection[i].clone()
		# Il biglietto di ritorno: se questa copia cresce in battaglia, è così che
		# si ritrova quale carta del mazzo è cresciuta.
		copy.origin = i
		_apply_passives(copy)
		out.append(copy)
	return out


## Porta nel mazzo le evoluzioni avvenute in battaglia — `{posto: id_nuovo}`,
## così come le ha contate il Duel. Restituisce quante ne ha applicate.
##
## **Vale anche se la battaglia è andata male**: la creatura è cresciuta e resta
## cresciuta. Perdere costa già delle vite, e i gaiofanamon sono l'unico
## archetipo che ha bisogno di tempo per pagare: annullargli la crescita proprio
## nei round difficili vorrebbe dire punirlo due volte.
##
## I sigilli si ricopiano dalla carta di prima: sono della carta, non del
## livello. Il resto — i passivi della run, il ritmo — si riapplica da solo a
## ogni `battle_deck()`, e infatti nel mazzo le carte stanno **nude**.
func evolvi(evoluzioni: Dictionary) -> int:
	var quante := 0
	for posto in evoluzioni:
		var i := int(posto)
		if i < 0 or i >= collection.size():
			continue
		var cresciuta := CardLibrary.build(String(evoluzioni[posto]))
		if cresciuta == null:
			continue
		for seal in collection[i].seals:
			cresciuta.add_seal(seal)
		collection[i] = cresciuta
		quante += 1
	return quante


## Le regole del vocabolario comune: le sa applicare `CardLibrary`, che è lo
## stesso posto da cui le prendono i mazzi degli avversari. Una copia sola.
func _apply_passives(card: Card) -> void:
	for passive in passives:
		if passive is Dictionary:
			CardLibrary.apply_rule(card, passive)


# --- reliquie ------------------------------------------------------------

## Mette in tasca una reliquia e ne applica subito gli effetti una tantum.
## Le reliquie non si tolgono più: niente da disfare.
func add_relic(relic: Dictionary, rng: RngStream = null) -> bool:
	if relic.is_empty() or has_relic(String(relic.get("id", ""))):
		return false

	var copia := relic.duplicate(true)
	if int(copia.get("rounds", 0)) > 0:
		copia["_dal_round"] = round_number
	relics.append(copia)

	if relic.has("max_hp_add"):
		max_hp = maxi(max_hp + int(relic["max_hp_add"]), 10)
	if relic.has("lives_add"):
		lives += int(relic["lives_add"])
	if relic.has("rule"):
		# La regola porta il nome di chi l'ha messa: serve a toglierla quando la
		# reliquia scade. Senza, un bonus a tempo resterebbe per sempre.
		var rule: Dictionary = (relic["rule"] as Dictionary).duplicate(true)
		rule["from"] = String(relic.get("id", ""))
		passives.append(rule)
	if relic.has("cards_add"):
		var stream := rng if rng != null else _rng
		for i in int(relic["cards_add"]):
			add_card(_carta_di_reliquia(relic, stream))

	changed.emit()
	return true


## Che carta tira fuori una reliquia. Tre modi, dal più preciso al più vago:
##
##   `cards_pool`   una lista di id con i loro pesi — "una a caso fra queste,
##                  ma quella lì una volta su cento"
##   `cards_family` una a caso di quel mazzo
##   niente         una a caso da tutti, come ha sempre fatto la bisaccia
func _carta_di_reliquia(relic: Dictionary, stream: RngStream) -> Card:
	var pool: Dictionary = relic.get("cards_pool", {})
	if not pool.is_empty():
		var ids: Array = pool.keys()
		var pesi: Array = []
		for id in ids:
			pesi.append(maxf(float(pool[id]), 0.0))
		return CardLibrary.build(String(stream.pick_weighted(ids, pesi)))

	var famiglie: Dictionary = {}
	if relic.has("cards_family"):
		famiglie[String(relic["cards_family"])] = 1.0
	return CardLibrary.random_card(stream, famiglie, relic.get("cards_range", [2, 8]))


## Le reliquie con `rounds` durano quel tanto e poi se ne vanno, portandosi via
## la regola che avevano installato.
func _scadi_reliquie() -> void:
	var restano: Array[Dictionary] = []
	for relic in relics:
		var durata := int(relic.get("rounds", 0))
		if durata <= 0:
			restano.append(relic)
			continue
		var da := int(relic.get("_dal_round", round_number))
		if round_number - da < durata:
			restano.append(relic)
			continue
		var id := String(relic.get("id", ""))
		passives = passives.filter(func(r: Dictionary) -> bool: return String(r.get("from", "")) != id)
	relics = restano


func has_relic(relic_id: String) -> bool:
	for relic in relics:
		if String(relic.get("id", "")) == relic_id:
			return true
	return false


func _relic_sum(key: String) -> int:
	var total := 0
	for relic in relics:
		total += int(relic.get(key, 0))
	return total


## Posti in più sulla plancia. Attenzione: è un'arma a doppio taglio — più
## carte in campo significa più effetti al secondo, ma anche un mazzo che si
## consuma più in fretta.
func board_bonus() -> int:
	return _relic_sum("board_add")


func extra_gold_per_round() -> int:
	return _relic_sum("gold_per_round_add")


func start_shield() -> int:
	return _relic_sum("start_shield")


## Quanto veleno e sanguinamento ti scrolli di dosso a ogni applicazione.
func status_resist() -> int:
	return _relic_sum("status_resist")


## Con quanta catena di One cominci la battaglia, invece che da zero.
func start_combo() -> int:
	return _relic_sum("start_combo")


## Quanto costa comprare, con gli sconti delle reliquie. Si moltiplicano fra
## loro: due sconti del 20% non fanno il 40%, fanno il 36%.
func price_multiplier() -> float:
	var factor := 1.0
	for relic in relics:
		factor *= float(relic.get("price_mult", 1.0))
	return maxf(factor, 0.2)


# --- mazzo ---------------------------------------------------------------

## Il mazzo non ha un tetto: si può comprare finché c'è oro. Il freno non è una
## regola, è il gioco stesso — ogni carta in più diluisce quelle buone, e un
## mazzo gonfio è un mazzo lento a tirare fuori quello che serve.
func add_card(card: Card) -> bool:
	if card == null:
		return false
	collection.append(card)
	changed.emit()
	return true


## Togliere carte è metà del deckbuilding, ma sotto una certa soglia il mazzo
## finisce prima di aver fatto qualcosa: sotto il minimo non si scende.
func remove_card(card: Card) -> bool:
	if card == null or collection.size() <= Cfg.get_int("deck.min_size", 10):
		return false
	var index := collection.find(card)
	if index < 0:
		return false
	collection.remove_at(index)
	changed.emit()
	return true


## Quante carte di quella famiglia ci sono nel mazzo. Serve agli incontri che
## capitano solo a chi ha già qualcosa: lo scambio del Gaiofanamon, il professore
## che non ne regala un secondo.
func count_family(family: String) -> int:
	var quante := 0
	for card in collection:
		if card.family == family:
			quante += 1
	return quante


func deck_size() -> int:
	return collection.size()


func can_remove() -> bool:
	return collection.size() > Cfg.get_int("deck.min_size", 10)


# --- oro -----------------------------------------------------------------

func gold() -> int:
	return wallet.get_amount_int(GOLD)


func earn(amount: int) -> void:
	if amount <= 0:
		return
	wallet.earn(GOLD, float(amount))
	changed.emit()


func spend(amount: int) -> bool:
	if not wallet.spend_one(GOLD, float(amount)):
		return false
	changed.emit()
	return true


# --- avanzamento ---------------------------------------------------------

## Chi hai davanti dipende da quante ne hai vinte, non da quante ne hai giocate:
## chi perde ritrova lo stesso avversario, e deve batterlo per andare oltre.
func opponent_for_round() -> Dictionary:
	# La partita di prova non è nella fila degli avversari: GiGi non è uno da
	# battere, e tenerlo fuori da `opponents.json` è quello che fa tornare il
	# conto fra le dieci vittorie e i dieci avversari.
	if tutorial and Content.has("tutorial", "gigi"):
		return Content.entry("tutorial", "gigi")

	var order: Array = Content.list("opponents")
	if order.is_empty():
		return {}
	return order[clampi(wins, 0, order.size() - 1)]


## Le carte che GiGi regala alla fine della partita di prova. Restituisce quante
## ne sono entrate davvero.
##
## Sta qui e non in `play.gd` per una ragione precisa: **una run simulata deve
## avere lo stesso mazzo di una giocata**. Se il regalo lo versasse la schermata,
## `balance_test` misurerebbe per sempre un mazzo di sole dodici carte di
## campagna — un mazzo che nessun giocatore ha mai in mano.
func regala_le_carte_del_tutorial() -> int:
	if not Content.has("tutorial", "regalo"):
		return 0
	var quante := 0
	for id in Content.entry("tutorial", "regalo").get("carte", []):
		if add_card(CardLibrary.build(String(id))):
			quante += 1
	return quante


# --- come è andata a finire ----------------------------------------------

## Dove `play.gd` lascia scritto quale finale è stato, e dove `game_over.gd` va a
## leggerlo. Serve perché `Router.game_over()` porta con sé un booleano, e i
## finali sono **tre**: non ogni sconfitta è la stessa sconfitta.
const CHIAVE_FINALE := "finale"


## Quale delle tre schermate finali si è meritato questa partita.
##
## L'abbandono non è una sconfitta: è la scelta di mollare le carte e andare via
## con lei, e il gioco la tratta come un finale suo — quello con il punto
## interrogativo nel titolo.
func finale() -> String:
	if victory:
		return "vittoria"
	if abandoned:
		return "abbandono"
	return "sconfitta"


# --- i mazzi che si svelano strada facendo -------------------------------
#
# One e Gaiofanamon non esistono per le prime due sfide: non in vetrina, non nei
# mazzi degli avversari, e nella scheda dell'avversario al loro posto ci sono dei
# "???". Compaiono alla terza bottega, che è dove GiGi li spiega.
#
# La soglia sta in `families.json` (`reveal_after_wins`) e non qui: un mazzo che
# arriverà dopo si aggiunge con una riga di JSON, senza toccare il codice.

## Vero se questo mazzo si può già vedere.
func mazzo_svelato(family: Dictionary) -> bool:
	return wins >= int(family.get("reveal_after_wins", 0))


func mazzo_svelato_per_id(family_id: String) -> bool:
	return not Content.has("families", family_id) \
		or mazzo_svelato(Content.entry("families", family_id))


## I pesi da passare a `CardLibrary` perché peschi **solo** dai mazzi già svelati.
## Nominarli tutti è quello che esclude gli altri: una ricetta che nomina delle
## famiglie esclude tutte quelle che non nomina.
func pesi_svelati() -> Dictionary:
	var out := {}
	for family in CardLibrary.pool_families():
		if mazzo_svelato(family):
			out[String(family.get("id", ""))] = float(family.get("default_weight", 1.0))
	return out


## La ricetta di un avversario, ripulita dai mazzi non ancora svelati.
##
## Se togliendoli non resta niente si ricade sui mazzi svelati coi loro pesi di
## default: meglio un avversario diverso dal previsto che un avversario senza
## carte — e senza questo ramo `random_card`, trovandosi con tutti i pesi a zero,
## tornerebbe ai default **compresi quelli nascosti**, rimettendo in campo proprio
## le carte che stiamo tenendo da parte.
func ricetta_svelata(recipe: Dictionary) -> Dictionary:
	var pesi: Dictionary = recipe.get("weights", {})
	var puliti := {}
	var totale := 0.0
	for id in pesi:
		if mazzo_svelato_per_id(String(id)):
			var peso := maxf(float(pesi[id]), 0.0)
			puliti[id] = peso
			totale += peso

	if totale <= 0.0:
		puliti = pesi_svelati()

	var copia := recipe.duplicate(true)
	copia["weights"] = puliti
	return copia


## Quante vittorie servono per portare a casa la partita.
func wins_needed() -> int:
	return maxi(Cfg.get_int("player.wins_to_win", 10), 1)


func total_rounds() -> int:
	return wins_needed()


## Vera quando la prossima vittoria chiude la partita.
func is_last_round() -> bool:
	return wins >= wins_needed() - 1


## Quante vite costa perdere **questo** round. Presto poco, tardi caro: nei
## primi round si può sbagliare e imparare, più avanti una sconfitta pesa tre
## volte tanto. La tabella sta in `tuning.json` (`player.life_cost`), una voce
## per round; oltre l'ultima vale l'ultima.
func life_cost() -> int:
	var tabella: Array = Cfg.get_value("player.life_cost", [1])
	if tabella.is_empty():
		return 1
	var indice := clampi(round_number - 1, 0, tabella.size() - 1)
	return maxi(int(tabella[indice]), 1)


## Chiude il round. Restituisce true se la run continua.
func finish_round(won: bool) -> bool:
	# La partita di prova si chiude e basta, comunque sia andata: né una vittoria
	# in più né una vita in meno. Chi la perde ha imparato lo stesso.
	if tutorial:
		tutorial = false
		regala_le_carte_del_tutorial()
		changed.emit()
		return true

	if won:
		wins += 1
		earn(Cfg.get_int("shop.win_bonus", 3))
		if wins >= wins_needed():
			victory = true
	else:
		var costo := life_cost()
		lives -= costo
		lives_lost += costo

	if victory or abandoned or lives <= 0:
		changed.emit()
		return false

	round_number += 1
	_scadi_reliquie()
	earn(Cfg.get_int("shop.gold_per_round", 6) + extra_gold_per_round())
	changed.emit()
	return true


## Il riepilogo di fine partita. **Le chiavi sono anche indici**, non solo
## etichette: `tuning.json` ne nomina una in `menu.best_stat` e `game_over.gd`
## ci ritrova dentro il record. Tradotte qui, il record sparisce senza nessun
## errore — si traducono dove si **mostrano**, mai a monte.
func stats() -> Dictionary:
	return {
		"Vittorie": wins,
		"Battaglie giocate": round_number,
		"Vite perse": lives_lost,
		"Vite rimaste": maxi(lives, 0),
		"Carte nel mazzo": collection.size(),
		"Oro avanzato": gold(),
	}


# --- salvataggio ---------------------------------------------------------
#
# LA REGOLA: si salva il RISULTATO, non la ricetta per riottenerlo.
#
# Le reliquie hanno due nature diverse e vanno trattate diversamente.
#   - Quelle che *sono* una regola (`rule`) o che si leggono a ogni chiamata
#     (`board_add`, `gold_per_round_add`, `start_shield`, `price_mult`)
#     tornano da sole appena la reliquia è di nuovo in tasca.
#   - Quelle una tantum (`max_hp_add`, `lives_add`, `cards_add`) hanno già
#     versato il loro effetto dentro max_hp, lives e collection nel momento
#     dell'acquisto.
# Per questo il ripristino NON passa da `add_relic()`: rimette le reliquie
# nella lista e basta. Chiamare add_relic qui regalerebbe 12 punti vita e due
# carte a ogni caricamento — e un passivo doppio per ogni reliquia con `rule`.

const SAVE_KEY := "run"


func to_dict() -> Dictionary:
	var cards: Array = []
	for card in collection:
		cards.append(card.to_dict())

	var relic_ids: Array = []
	for relic in relics:
		relic_ids.append(String(relic.get("id", "")))

	return {
		"round": round_number,
		"wins": wins,
		"lives": lives,
		"lives_lost": lives_lost,
		"max_hp": max_hp,
		"gold": gold(),
		"victory": victory,
		"cards": cards,
		"relics": relic_ids,
		"passives": passives.duplicate(true),
		"dialoghi": dialoghi_visti.duplicate(),
		"tutorial": tutorial,
	}


static func from_dict(data: Dictionary, rng: RngStream = null) -> RunState:
	var run := RunState.new(rng)

	run.round_number = maxi(int(data.get("round", 1)), 1)
	run.wins = maxi(int(data.get("wins", 0)), 0)
	run.lives = int(data.get("lives", run.lives))
	run.lives_lost = maxi(int(data.get("lives_lost", 0)), 0)
	for raw in data.get("dialoghi", []):
		run.dialoghi_visti.append(String(raw))
	# Falso di default: un salvataggio scritto prima che il tutorial esistesse è
	# di qualcuno che il tutorial l'ha già passato — rifarglielo sarebbe peggio
	# che saltarlo.
	run.tutorial = bool(data.get("tutorial", false))
	run.max_hp = maxi(int(data.get("max_hp", run.max_hp)), 1)
	run.victory = bool(data.get("victory", false))
	run.wallet.set_amount(GOLD, float(data.get("gold", 0)))

	# _init() ha già costruito il mazzo iniziale: quello salvato lo sostituisce.
	run.collection.clear()
	for raw in data.get("cards", []):
		if not (raw is Dictionary):
			continue
		var card := Card.from_dict(raw)
		if card != null:
			run.collection.append(card)

	# Solo gli id: il testo, il costo e i numeri della reliquia vengono dai JSON,
	# così ribilanciare `relics.json` vale anche per le partite già in corso.
	run.relics.clear()
	for raw in data.get("relics", []):
		var relic_id := String(raw)
		if Content.has("relics", relic_id):
			run.relics.append(Content.instance("relics", relic_id))

	run.passives.clear()
	for raw in data.get("passives", []):
		if raw is Dictionary:
			run.passives.append(_aggiorna_famiglia((raw as Dictionary).duplicate(true)))

	return run


## Le famiglie si chiamavano "city" e "country". I passivi sono l'unico posto in
## cui un nome di famiglia finisce dentro un salvataggio: senza questa traduzione
## una reliquia comprata prima del cambio smetterebbe di applicarsi, in silenzio.
const FAMIGLIE_RINOMINATE := {"city": "poker", "country": "briscola"}

static func _aggiorna_famiglia(rule: Dictionary) -> Dictionary:
	var vecchia := String(rule.get("family", ""))
	if FAMIGLIE_RINOMINATE.has(vecchia):
		rule["family"] = FAMIGLIE_RINOMINATE[vecchia]
	return rule


## Scrive subito su disco: se il giocatore chiude la finestra a metà bottega
## non deve perdere il round.
func save() -> void:
	Save.set_value(SAVE_KEY, to_dict())
	Save.flush()


## La partita interrotta, o null se non ce n'è una. È quello che serve al
## pulsante "Continua" del menu.
static func load_saved(rng: RngStream = null) -> RunState:
	var data: Variant = Save.get_value(SAVE_KEY)
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	return RunState.from_dict(data as Dictionary, rng)


static func has_saved() -> bool:
	var data: Variant = Save.get_value(SAVE_KEY)
	return data is Dictionary and not (data as Dictionary).is_empty()


## Da chiamare quando la run finisce (vittoria o sconfitta): la partita in corso
## non esiste più e "Continua" deve sparire.
static func clear_save() -> void:
	Save.erase(SAVE_KEY)
	Save.flush()
