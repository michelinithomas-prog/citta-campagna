class_name Duel
extends RefCounted
## Il duello: due plance che si consumano da sole a tick fissi.
##
## Il giocatore non tocca niente — ha già deciso tutto nel negozio. Qui c'è solo
## la simulazione, che gira su SimClock ed è quindi deterministica: stesso seed e
## stesso mazzo danno sempre lo stesso esito, in gioco come nei test.
##
##   var duel := Duel.new(mio_lato, suo_lato, Rng.stream)
##   duel.advance(delta)        # dal _process della scena
##   duel.simulate_to_end()     # nei test, istantaneo
##
## Si perde in due modi, ed è il cuore del gioco che siano due: gli HP a zero
## (ti hanno ucciso) e la pila esaurita (hai finito le carte da giocare).

signal card_activated(side: Side, slot: int, card: Card)
signal card_burned(side: Side, slot: int, card: Card)

## Una carta ha lasciato il suo slot, e **perché**. Serve a chi disegna: un
## rimpiazzo normale, una carta rubata e una che è cresciuta di livello sono lo
## stesso gesto per la simulazione e tre cose diverse da guardare.
##
## `card` è la carta che se ne va — con l'evoluzione è già quella cresciuta, che
## è l'unica interessante da mostrare.
signal card_left(side: Side, slot: int, card: Card, motivo: String)

signal ended(player_won: bool, reason: String)
signal state_changed

## I cinque modi in cui una carta lascia lo slot, per `card_left`.
const MOTIVO_SCARTATA := "scartata"
const MOTIVO_RICICLATA := "riciclata"
const MOTIVO_EVOLUTA := "evoluta"
const MOTIVO_BRUCIATA := "bruciata"
const MOTIVO_RUBATA := "rubata"

## Rete di sicurezza: il mazzo che si consuma garantisce già la fine, questo
## serve solo a non far girare a vuoto un test se una regola nuova sbaglia.
const MAX_SECONDS := 180.0

var player: Side
var foe: Side
var clock: SimClock
var resolver: EffectResolver

var is_over := false
var won := false
var reason := ""
var elapsed := 0.0
var activations := 0

## Le creature del **giocatore** che sono cresciute, `{posto nel mazzo: id nuovo}`.
## Le raccoglie qui perché l'evoluzione dura per il resto della partita, e chi
## chiude la battaglia deve poterle riportare nel mazzo con una riga sola
## (`RunState.evolvi`). Una carta che cresce due volte nella stessa battaglia
## lascia solo l'ultimo livello: si sovrascrive da sé.
##
## Quelle dell'avversario non ci finiscono: il suo mazzo si ritira a ogni round.
var evoluzioni: Dictionary = {}

## Quanto manca al prossimo secondo di veleno, sanguinamento e aure. Il tempo
## degli stati alterati scorre a passi di un secondo, non di un tick.
var _dot_accumulator := 0.0
var _poison_accumulator := 0.0

var _rng: RngStream


func _init(player_side: Side, foe_side: Side, rng: RngStream = null, tick: float = 0.05) -> void:
	_rng = rng if rng != null else RngStream.new(1)
	player = player_side
	foe = foe_side

	clock = SimClock.new(tick)
	clock.ticked.connect(_on_tick)

	resolver = EffectResolver.new(_rng)
	_register_effects()

	# Prima di begin(): la plancia si riempie lì dentro, e chi entra deve poter
	# far scattare la catena e i propri effetti d'ingresso fin dalla prima carta.
	player.slot_filled.connect(_on_slot_filled.bind(player, foe))
	foe.slot_filled.connect(_on_slot_filled.bind(foe, player))

	player.begin()
	foe.begin()
	# Nessun _check_end() qui, di proposito. Se un lato nasce già spacciato —
	# mazzo più corto della plancia — chiudere adesso emetterebbe `ended` prima
	# che la scena abbia avuto modo di collegarcisi: il segnale andrebbe perso e
	# la partita resterebbe ferma sulla schermata di battaglia per sempre.
	# Ci pensa il primo tick, quando il pubblico è arrivato.


## Da chiamare ogni frame finché il duello non finisce.
func advance(delta: float) -> void:
	if is_over:
		return
	clock.advance(delta)
	state_changed.emit()


## Risolve tutto subito: test e comando di debug "skip".
func simulate_to_end() -> bool:
	while not is_over:
		clock.advance_seconds(clock.step)
	return won


func speed_up(multiplier: float) -> void:
	clock.speed = maxf(multiplier, 0.1)


func other_side(side: Side) -> Side:
	return foe if side == player else player


# --- simulazione ---------------------------------------------------------

func _on_tick(_index: int, step: float) -> void:
	if is_over:
		return

	elapsed += step
	if elapsed >= MAX_SECONDS:
		_finish(player.hp_ratio() >= foe.hp_ratio(), "tempo")
		return

	_tick_statuses(step)
	if is_over:
		return

	# Sempre lo stesso ordine — prima il giocatore, poi l'avversario, slot per
	# slot. È l'unica cosa che tiene in piedi la riproducibilità.
	_run_side(player, foe, step)
	if is_over:
		return
	_run_side(foe, player, step)
	_check_end()


## Veleno, sanguinamento e aure scattano una volta al secondo, **prima** di ogni
## attivazione e per tutti e due i lati nello stesso istante: l'asimmetria del
## giocatore-che-scorre-per-primo vale per le carte, non per le ferite.
##
## `while` e non `if`: `simulate_to_end` avanza a passi di un tick, ma
## `advance_seconds` può saltarne più di venti in un colpo, e con un `if` i
## secondi in mezzo andrebbero perduti — i test sarebbero verdi da una parte e
## rossi dall'altra senza che niente sia cambiato.
##
## Un solo `_check_end()` alla fine: due lati che muoiono di veleno nello stesso
## secondo devono finire nel ramo del pareggio, non essere decisi dall'ordine
## in cui li scorriamo.
func _tick_statuses(step: float) -> void:
	_dot_accumulator += step
	while _dot_accumulator >= 1.0 - SimClock.EPSILON:
		_dot_accumulator -= 1.0
		player.tick_bleed()
		foe.tick_bleed()
		_run_auras(player, foe)
		_run_auras(foe, player)

	# Il veleno ha un passo suo, più lento: vedi Side.tick_poison().
	var passo := maxf(Cfg.get_float("battle.poison_every", 3.0), 0.1)
	_poison_accumulator += step
	while _poison_accumulator >= passo - SimClock.EPSILON:
		_poison_accumulator -= passo
		player.tick_poison()
		foe.tick_poison()

	_check_end()


## Gli effetti marcati `"when": "tick"`: valgono per ogni secondo in cui la carta
## resta in plancia, invece che alla sua attivazione. È così che un seme d'erba
## cura mentre aspetta.
##
## Qui dentro **non si tira nessun dado**: un `chance` in un'aura sposterebbe lo
## stream a ogni secondo di ogni battaglia, e ogni seed smetterebbe di valere.
## Se ne accorge `data_test`, non la buona volontà.
func _run_auras(side: Side, other: Side) -> void:
	if side.is_out:
		return
	for slot in side.board_size:
		var card: Card = side.board[slot]
		if card == null or card.tick_effects.is_empty():
			continue
		resolver.resolve_all(card.tick_effects, {
			"card": card, "side": side, "foe": other, "duel": self, "slot": slot,
		})


## Una carta è appena entrata in uno slot. Due cose succedono qui, e solo qui:
## la catena di One si allunga se la carta che arriva somiglia a quella che se
## n'è andata, e gli effetti `"when": "enter"` si risolvono — è il Blocco, che
## esiste per spegnere la catena.
##
## L'ordine conta: prima la catena, poi l'ingresso. Un Blocco che entra dopo una
## corrispondenza deve trovare la catena allungata e spegnerla lo stesso,
## altrimenti basterebbe farlo entrare al momento giusto per salvarla.
func _on_slot_filled(slot: int, card: Card, side: Side, other: Side) -> void:
	if card == null:
		return

	var uscita: Card = side.last_left[slot]
	if uscita != null and card.combos_with(uscita):
		side.add_combo(1)

	if not card.enter_effects.is_empty():
		resolver.resolve_all(card.enter_effects, {
			"card": card, "side": side, "foe": other, "duel": self, "slot": slot,
		})


func _run_side(side: Side, other: Side, step: float) -> void:
	for slot in side.advance_cooldowns(step):
		if is_over or side.is_out:
			return
		_activate(side, other, slot)


func _activate(side: Side, other: Side, slot: int) -> void:
	var card := side.board[slot]
	if card == null:
		return

	var context := {"card": card, "side": side, "foe": other, "duel": self, "slot": slot}
	card_activated.emit(side, slot, card)
	resolver.resolve_all(card.effects, context)
	activations += 1

	# Se l'effetto ha già chiuso la partita ci si ferma qui: chi è morto prima
	# ha perso prima, anche se chi ha sparato stava per finire le carte.
	_check_end()
	if is_over:
		return

	_dopo_l_attivazione(side, slot, card, context)

	# Il rimpiazzo è il momento in cui si scopre di non avere più carte.
	side.refill()
	_check_end()


## Dove va a finire la carta che ha appena sparato, e chi prende il suo posto.
## Un punto solo, con la precedenza scritta: quattro strade che si escludono, e
## se ognuna si servisse da sola prima o poi due si calpesterebbero.
##
##   1. rubata      qualcuno ha messo una carta nemica in questo slot
##   2. evoluta     sale di livello e va negli scarti al posto suo
##   3. riciclata   torna in fondo alla pila (il sigillo Eco)
##   4. scartata    la strada di tutti i giorni
func _dopo_l_attivazione(side: Side, slot: int, card: Card, context: Dictionary) -> void:
	side.take_from(slot)

	var rubata: Card = context.get("stolen")
	var evoluta := _evolvi(card)

	if evoluta != null:
		side.discard(evoluta)
		# La crescita esce dalla battaglia: qui si annota, il mazzo la incasserà
		# a fine round. Solo per il giocatore, e solo se la carta viene dal suo
		# mazzo — un Germoglio o una creatura evocata dall'Antigh non hanno un
		# posto a cui tornare.
		if side == player and evoluta.origin >= 0:
			evoluzioni[evoluta.origin] = evoluta.id
		card_left.emit(side, slot, evoluta, MOTIVO_EVOLUTA)
	elif bool(context.get("recycled", false)):
		side.recycle(card)
		card_left.emit(side, slot, card, MOTIVO_RICICLATA)
	else:
		side.discard(card)
		card_left.emit(side, slot, card, MOTIVO_SCARTATA)

	if rubata != null:
		side.put_in(slot, rubata)


## Il livello successivo della stessa creatura, o null se non ne ha uno.
## Si porta dietro sigilli, passivi della run e ritmo: è la stessa carta più
## grande, non una carta nuova che le somiglia.
func _evolvi(card: Card) -> Card:
	if card == null or card.evolves_to.is_empty():
		return null
	var evoluta := CardLibrary.build_from(card.suit_id, card.evolves_to)
	if evoluta == null:
		return null

	evoluta.origin = card.origin
	evoluta.cooldown_scale = card.cooldown_scale
	for seal in card.seals:
		evoluta.add_seal(seal)
	for mod in card.stats.mods_from("run"):
		evoluta.stats.add_mod(String(mod["stat"]), int(mod["kind"]), float(mod["value"]), "run")
	return evoluta


func _check_end() -> void:
	if is_over:
		return
	if player.is_out and foe.is_out:
		# Caduti nello stesso istante: decide chi sta in piedi meglio, e la
		# parità non regala la vittoria al giocatore.
		_finish(player.hp_ratio() > foe.hp_ratio(), "pareggio")
	elif foe.is_out:
		_finish(true, foe.defeat_reason)
	elif player.is_out:
		_finish(false, player.defeat_reason)


func _finish(player_won: bool, why: String) -> void:
	if is_over:
		return
	is_over = true
	won = player_won
	reason = why
	resolver.clear_handlers()
	state_changed.emit()
	ended.emit(player_won, why)


# --- effetti -------------------------------------------------------------
#
# AGGIUNGERE UN EFFETTO: una register() qui e una riga nel JSON del seme (o in
# specials.json per una carta sola). Nel contesto: "card" (chi si attiva),
# "side" (il suo schieramento), "foe" (l'altro), "duel".

func _register_effects() -> void:
	## Il colpo. `"pierce": true` lo fa passare attraverso lo scudo — è un
	## aggettivo del danno, non un effetto a parte: così si compone da solo con
	## `chance`, `repeat`, i sigilli e i moltiplicatori di valore.
	## `"target": "self"` lo gira contro chi lo lancia: le carte di Picche
	## pagano quello che offrono.
	resolver.register("damage", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx)
		if target == null:
			return 0
		var inflitto := target.take_damage(_amount_combo(effect, ctx), bool(effect.get("pierce", false)))
		_lifesteal(ctx, inflitto)
		return inflitto
	)

	resolver.register("heal", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target != null:
			target.heal(_amount_combo(effect, ctx))
		return null
	)

	resolver.register("shield", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target != null:
			target.add_shield(_amount_combo(effect, ctx))
		return null
	)

	## Un `amount` negativo toglie oro invece di darne: è il prezzo delle carte
	## che offrono più di quanto dovrebbero.
	resolver.register("gold", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target == null:
			return null
		var quanto := _amount(effect, ctx)
		if quanto >= 0:
			target.earn_gold(quanto)
		else:
			target.spend_gold(-quanto)
		return null
	)

	## Brucia le carte avversarie più vicine a partire: le scarta senza farle
	## risolvere e costringe l'avversario a pescare. È il modo di attaccare il
	## mazzo invece della vita — chi gioca di controllo vince così.
	resolver.register("burn", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target: Side = ctx.get("foe")
		if target == null:
			return 0
		var burned := 0
		for i in maxi(_amount(effect, ctx), 1):
			var slot := target.most_imminent_slot()
			if slot < 0:
				break
			var card := target.take_from(slot)
			target.discard(card)
			card_burned.emit(target, slot, card)
			card_left.emit(target, slot, card, MOTIVO_BRUCIATA)
			burned += 1
			target.refill()
			if target.is_out:
				break
		return burned
	)

	resolver.register("slow", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target: Side = ctx.get("foe")
		if target == null:
			return null
		var delay := resolver.value(effect, "amount", ctx, 1.0)
		for card in target.cards_on_board():
			card.cooldown += delay
		return null
	)

	## Affretta le proprie carte. Non risolve mai a catena: una carta portata a
	## zero parte al tick successivo, altrimenti due sproni potrebbero
	## rimbalzarsi l'attivazione all'infinito dentro un solo tick.
	resolver.register("haste", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target: Side = ctx.get("side")
		var self_card: Card = ctx.get("card")
		if target == null:
			return null
		var gain := resolver.value(effect, "amount", ctx, 1.0)
		for card in target.cards_on_board():
			if card != self_card:
				card.cooldown = maxf(card.cooldown - gain, SimClock.EPSILON * 2.0)
		return null
	)

	## La carta torna in fondo alla pila invece di finire negli scarti: l'unico
	## modo di allontanare il deck-out.
	resolver.register("recycle", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var card: Card = ctx.get("card")
		if card == null:
			return false
		var limit := int(resolver.value(effect, "times", ctx, 1.0))
		var used := int(card.uses.get("recycle", 0))
		if used >= limit:
			return false
		card.uses["recycle"] = used + 1
		ctx["recycled"] = true
		return true
	)

	## Allunga la catena di One. Il Pesca Due ne vale due, il Pesca Quattro
	## quattro — e proprio perché li regala tutti insieme, il Quattro si porta
	## dietro un Blocco da mettere nel proprio mazzo.
	resolver.register("combo", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target != null:
			target.add_combo(maxi(_amount(effect, ctx), 1))
		return null
	)

	## La spegne. È l'unico effetto della carta Blocco, e scatta quando **entra**
	## in plancia, non quando si attiva: il danno è arrivare, non partire.
	resolver.register("combo_reset", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target != null:
			target.reset_combo()
		return null
	)

	_register_stati()
	_register_carte()


# --- stati alterati e modificatori ---------------------------------------

func _register_stati() -> void:
	## Sanguinamento: fa il suo numero di danni ogni secondo, poi cala di uno.
	## Colpo forte adesso che si spegne da solo — il contrario del veleno.
	resolver.register("bleed", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx)
		if target != null:
			target.apply_bleed(_amount(effect, ctx))
		return null
	)

	## Veleno: piccolo, fisso, e non se ne va. Vale il suo numero moltiplicato
	## per i secondi che restano, quindi si applica **a stack singoli**: una
	## carta che ne mettesse cinque in un colpo chiuderebbe la partita da sola.
	resolver.register("poison", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx)
		if target != null:
			target.apply_poison(_amount(effect, ctx))
		return null
	)

	## Lava via veleno e sanguinamento. È la risposta ai danni nel tempo: lo
	## scudo, contro quelli, non serve a niente.
	resolver.register("cleanse", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		return target.cleanse() if target != null else 0
	)

	## Ferma il tempo sulle carte avversarie per X secondi. Con `"amount"` si
	## danno i secondi; senza `"all": true` colpisce solo quella più imminente,
	## che è il bersaglio che fa più male.
	resolver.register("paralyze", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx)
		if target == null:
			return null
		var secondi := resolver.value(effect, "amount", ctx, 1.0)
		target.paralyze(secondi, -1 if bool(effect.get("all", false)) else target.most_imminent_slot())
		return null
	)

	## Potenzia uno slot. Il buff è del posto, non della carta: chi passa di lì
	## ne gode. Uno per slot, e **il nuovo cancella il vecchio** — con tre
	## sorgenti di buff in giro, sommarli renderebbe la plancia illeggibile.
	##
	##   "slots": "self" (default) · "all" · "others"
	##   dentro "buff": value_add, value_mult, cooldown_mult, lifesteal
	resolver.register("slot_buff", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target == null:
			return null
		var buff: Dictionary = effect.get("buff", {})
		var mio := int(ctx.get("slot", -1))
		for slot in _slots_bersaglio(String(effect.get("slots", "self")), mio, target.board_size):
			target.set_slot_buff(slot, buff)
		return null
	)

	## Un bonus che vale fino alla fine della battaglia, su tutte le proprie
	## carte — quelle in campo adesso e quelle che arriveranno. È il Re.
	resolver.register("match_buff", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target != null:
			target.add_match_mod("value", StatBlock.FLAT, resolver.value(effect, "amount", ctx, 1.0))
		return null
	)

	## Smorza le carte avversarie in plancia: valgono meno finché restano lì.
	## Il modificatore muore quando la carta lascia il posto — è un colpo al
	## presente, non una condanna.
	resolver.register("value_debuff", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx)
		if target == null:
			return null
		var quanto := resolver.value(effect, "amount", ctx, 1.0)
		for card in target.cards_on_board():
			card.stats.add_mod("value", StatBlock.FLAT, -absf(quanto), Card.MOD_BATTLE)
		return null
	)


# --- carte che si muovono ------------------------------------------------

func _register_carte() -> void:
	## Fa scartare all'avversario le carte in cima al mazzo. Non lo uccide
	## adesso: gli toglie il futuro, e il conto arriva quando dovrà rimpiazzare
	## una carta e non troverà più niente.
	resolver.register("mill", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx)
		return target.pile.mill(maxi(_amount(effect, ctx), 1)) if target != null else 0
	)

	## Ripesca dagli scarti e rimette in fondo alla pila. È il gesto che allontana
	## il deck-out, ed è anche l'unico modo di rivedere una carta evoluta.
	resolver.register("recover", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target == null:
			return 0
		return target.pile.recover(_rng, maxi(_amount(effect, ctx), 1)).size()
	)

	## Toglie all'avversario la carta più vicina a partire e la mette al proprio
	## posto. Lui dovrà pescarne un'altra: è un colpo alla plancia *e* al mazzo.
	resolver.register("steal", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target: Side = ctx.get("foe")
		var mine: Side = ctx.get("side")
		if target == null or mine == null:
			return null
		var slot := target.most_imminent_slot()
		if slot < 0:
			return null
		var rubata := target.take_from(slot)
		card_left.emit(target, slot, rubata, MOTIVO_RUBATA)
		target.refill()
		# Non entra subito in plancia: lo slot di chi ruba è ancora occupato da
		# lei stessa. Decide _dopo_l_attivazione, che è l'unico posto in cui si
		# stabilisce chi occupa uno slot.
		ctx["stolen"] = rubata
		return rubata
	)

	## Mette in cima al proprio mazzo una carta nata adesso: un seme d'erba, un
	## gaiofanamon di livello uno. Sono cloni di battaglia, quindi a fine partita
	## spariscono da sole — la collezione della run non le vede mai.
	resolver.register("spawn_card", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var target := _target(effect, ctx, true)
		if target == null:
			return null
		var quante := maxi(_amount(effect, ctx), 1)
		var nate := 0
		for i in quante:
			# `card` è una carta precisa, `cards` un sacchetto da cui pescare:
			# L'antigh sveglia *una* creatura, e non sempre la stessa.
			var quale := String(effect.get("card", ""))
			var sacchetto: Array = effect.get("cards", [])
			if not sacchetto.is_empty():
				quale = String(_rng.pick(sacchetto))
			var card: Card = target.card_maker.call(quale)
			if card == null:
				break
			# Dove finisce cambia tutto: in cima scende in campo al primo
			# rimpiazzo, mescolata uscirà chissà quando. Il Germoglio vuole la
			# cima, il Blocco del Pesca Quattro vuole il fondo del sacco.
			match String(effect.get("where", "top")):
				"random":
					target.pile.insert_random(card, _rng)
				"bottom":
					target.pile.recycle(card)
				_:
					target.pile.insert_top(card)
			nate += 1
		return nate
	)


# --- attrezzi per gli handler --------------------------------------------

## Chi subisce l'effetto. Di norma l'avversario per i colpi e sé stessi per i
## rimedi; `"target": "self"` (o `"foe"`) lo dice esplicitamente, ed è così che
## una carta si fa male da sola invece di far male a qualcun altro.
func _target(effect: Dictionary, ctx: Dictionary, amico: bool = false) -> Side:
	var mine: Side = ctx.get("side")
	var theirs: Side = ctx.get("foe")
	match String(effect.get("target", "")):
		"self":
			return mine
		"foe":
			return theirs
		_:
			return mine if amico else theirs


## Gli slot che un buff tocca. "self" è quello della carta che l'ha lanciato.
func _slots_bersaglio(quali: String, mio: int, quanti: int) -> Array[int]:
	var out: Array[int] = []
	match quali:
		"all":
			for slot in quanti:
				out.append(slot)
		"others":
			for slot in quanti:
				if slot != mio:
					out.append(slot)
		_:
			if mio >= 0:
				out.append(mio)
	return out


## La cura che si porta via chi colpisce da uno slot potenziato. Si applica sul
## danno **arrivato agli HP**, non su quello dichiarato: contro uno scudo pieno
## non cura niente, ed è la limitazione giusta.
func _lifesteal(ctx: Dictionary, inflitto: int) -> void:
	if inflitto <= 0:
		return
	var mine: Side = ctx.get("side")
	var slot := int(ctx.get("slot", -1))
	if mine == null or slot < 0:
		return
	var quota := float(mine.slot_buff(slot).get("lifesteal", 0.0))
	if quota > 0.0:
		mine.heal(int(roundf(inflitto * quota)))


func _amount(effect: Dictionary, context: Dictionary) -> int:
	return int(roundf(resolver.value(effect, "amount", context, 0.0)))


## Come `_amount`, ma moltiplicato per la catena di chi sta giocando la carta.
## Vale per colpi, cure e scudi — le tre cose che la catena di One aumenta — e
## per **tutte** le carte del lato, non solo per quelle di One: la catena non è
## un potere del mazzo, è uno stato di chi la sta tenendo in piedi.
func _amount_combo(effect: Dictionary, context: Dictionary) -> int:
	var mine: Side = context.get("side")
	var grezzo := resolver.value(effect, "amount", context, 0.0)
	if mine != null:
		grezzo *= mine.combo_multiplier()
	return int(roundf(grezzo))
