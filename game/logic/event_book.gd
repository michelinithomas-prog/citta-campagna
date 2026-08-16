class_name EventBook
extends RefCounted
## Gli incontri fra un round e l'altro: due o tre scelte, e qualcuna che può
## andare storta.
##
## Gli effetti passano dallo stesso EffectResolver della battaglia — così i
## meta-effetti `chance` e `random` arrivano gratis e restano riproducibili con
## lo stesso seed — ma con handler tutti suoi, perché qui non si tocca una
## plancia: si tocca la run.
##
## Chi lo istanzia deve chiamare clear_handlers() quando ha finito: gli handler
## catturano il libro e senza quello non viene liberato niente.

signal resolved(lines: Array)

var resolver: EffectResolver

var _rng: RngStream
var _seen: Array[String] = []


func _init(rng: RngStream = null) -> void:
	_rng = rng if rng != null else RngStream.new(1)
	resolver = EffectResolver.new(_rng)
	_register_effects()


func clear_handlers() -> void:
	resolver.clear_handlers()


## Capita un evento questo round? Non al primo, e non sempre.
func should_trigger(round_number: int, run: RunState = null) -> bool:
	if round_number < Cfg.get_int("events.min_round", 2):
		return false
	if available(round_number, run).is_empty():
		return false
	return _rng.chance(Cfg.get_float("events.chance", 0.5))


## Gli incontri ancora possibili. Alcuni hanno una condizione — lo scambio del
## Gaiofanamon non ha senso a chi non ne ha uno — e senza `run` non si può
## verificarla: in quel caso restano fuori, che è il caso prudente.
func available(round_number: int, run: RunState = null) -> Array:
	return Content.filter("events", func(entry: Dictionary) -> bool:
		if _seen.has(String(entry.get("id", ""))) or round_number < int(entry.get("min_round", 1)):
			return false
		return _condizione_soddisfatta(entry.get("requires", {}), run)
	)


## `requires` capisce due cose: `{"family": "gaiofanamon"}` — averne almeno una
## in mazzo — e `{"family": "...", "none": true}`, cioè non averne nessuna.
func _condizione_soddisfatta(requires: Dictionary, run: RunState) -> bool:
	if requires.is_empty():
		return true
	if run == null:
		return false
	if requires.has("family"):
		var quante := run.count_family(String(requires["family"]))
		return quante == 0 if bool(requires.get("none", false)) else quante > 0
	return true


## Pesca un evento mai visto in questa run. Vuoto se non ce ne sono.
func draw(round_number: int, run: RunState = null) -> Dictionary:
	var pool := available(round_number, run)
	if pool.is_empty():
		return {}
	var event: Dictionary = _rng.pick(pool)
	_seen.append(String(event.get("id", "")))
	return event


## Applica una scelta e restituisce le righe da mostrare al giocatore.
func choose(event: Dictionary, index: int, run: RunState) -> Array:
	var choices: Array = event.get("choices", [])
	if index < 0 or index >= choices.size():
		return []

	var choice: Dictionary = choices[index]
	var context := {"run": run, "log": []}
	resolver.resolve_all(choice.get("effects", []), context)

	var lines: Array = context["log"]
	if lines.is_empty():
		lines = ["Non è successo niente."]
	resolved.emit(lines)
	return lines


# --- effetti fuori battaglia --------------------------------------------
#
# Contesto: "run" (lo stato della partita) e "log" (le righe da mostrare).

func _register_effects() -> void:
	resolver.register("run_gold", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		var amount := int(roundf(resolver.value(effect, "amount", ctx, 0.0)))
		if run == null or amount == 0:
			return null
		if amount > 0:
			run.earn(amount)
			ctx["log"].append(tr("+%d oro") % amount)
		else:
			# Il conto si fa PRIMA di pagare: dopo `spend` l'oro e' gia' sceso,
			# e con meno oro del dovuto il resoconto diceva «−-3 oro».
			var pagato := mini(-amount, run.gold())
			run.spend(pagato)
			ctx["log"].append(tr("−%d oro") % pagato)
		return null
	)

	resolver.register("run_max_hp", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		var amount := int(roundf(resolver.value(effect, "amount", ctx, 0.0)))
		if run == null or amount == 0:
			return null
		run.max_hp = maxi(run.max_hp + amount, 10)
		ctx["log"].append(tr("%+d di vita massima") % amount)
		return null
	)

	resolver.register("run_life", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		var amount := int(roundf(resolver.value(effect, "amount", ctx, 0.0)))
		if run == null or amount == 0:
			return null
		run.lives += amount
		# Le vite si guadagnano una per volta, e "+1 vite" non si può scrivere:
		# due frasi intere, non una desinenza rattoppata dentro il formato.
		ctx["log"].append(Testo.plurale(amount, "%+d vita", "%+d vite") % amount)
		return null
	)

	## Aggiunge una carta: quella scritta nell'evento, oppure una pescata dai
	## criteri (famiglia, fascia di valori).
	resolver.register("run_add_card", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		if run == null:
			return null
		var card: Card = null
		if effect.has("card"):
			card = CardLibrary.build(String(effect["card"]))
		else:
			# Nessun peso = i default di families.json. Con una famiglia
			# richiesta basta nominare quella: le altre valgono zero da sole.
			var weights: Dictionary = {}
			if effect.has("family"):
				weights[String(effect["family"])] = 1.0
			card = CardLibrary.random_card(_rng, weights, effect.get("value_range", []))
		if card == null or not run.add_card(card):
			return null
		ctx["log"].append(tr("entra nel mazzo: %s") % tr(card.display_name))
		return null
	)

	## Una reliquia: quella nominata, o una a caso fra quelle che non hai già.
	resolver.register("run_relic", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		if run == null:
			return null

		var relic: Dictionary = {}
		if effect.has("relic"):
			var id := String(effect["relic"])
			if Content.has("relics", id):
				relic = Content.instance("relics", id)
		else:
			var pool := Content.filter("relics", func(entry: Dictionary) -> bool:
				return bool(entry.get("in_shop", true)) and not run.has_relic(String(entry.get("id", "")))
			)
			if not pool.is_empty():
				relic = (_rng.pick(pool) as Dictionary).duplicate(true)

		if relic.is_empty() or not run.add_relic(relic, _rng):
			return null
		ctx["log"].append(tr("in tasca: %s") % tr(String(relic.get("name", "una reliquia"))))
		return null
	)

	## Chiude la partita qui. C'è una scelta che la finisce, ed è quella giusta.
	resolver.register("run_end", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		if run == null:
			return null
		run.abandoned = true
		ctx["log"].append(String(effect.get("text", "La partita finisce qui.")))
		return null
	)

	## Qualcosa che vale **solo per la prossima battaglia**: ci arrivi acciaccato,
	## o ci arrivi con le carte ancora intorpidite. Poi si consuma.
	resolver.register("run_next_battle", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		if run == null:
			return null
		for key in ["hp_mult", "paralyzed"]:
			if effect.has(key):
				run.next_battle[key] = float(effect[key])
		ctx["log"].append(String(effect.get("text", "la prossima battaglia comincerà male")))
		return null
	)

	## Lo scambio: via una carta di quella famiglia, dentro un'altra della stessa
	## famiglia e dello stesso stadio ma di un altro seme. Il ragazzino ci tiene.
	resolver.register("run_swap_suit", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		if run == null:
			return null
		var family := String(effect.get("family", ""))

		var candidate: Array[Card] = []
		for card in run.collection:
			if card.family == family:
				candidate.append(card)
		if candidate.is_empty():
			return null

		var vecchia: Card = _rng.pick(candidate)
		var rank := Content.entry("ranks", vecchia.rank_id)
		# Non basta "un altro seme della stessa famiglia": deve fare una carta che
		# esiste davvero. L'antigh ha un valore tutto suo e nessun seme se lo può
		# prendere; l'elettro si ferma al secondo livello e non ha un veterano. Con
		# il solo filtro sulla famiglia si finiva a costruire `fuoco_a0`, che
		# restituisce null — e l'incontro non faceva niente senza dirlo.
		var altri := Content.filter("suits", func(entry: Dictionary) -> bool:
			return String(entry.get("id", "")) != vecchia.suit_id \
				and bool(entry.get("in_pool", true)) \
				and CardLibrary.is_valid_pair(entry, rank)
		)
		if altri.is_empty():
			return null

		# Stesso stadio: si scambia una creatura con un'altra, non con un cucciolo.
		var nuova := CardLibrary.build_from(String((_rng.pick(altri) as Dictionary).get("id", "")), vecchia.rank_id)
		if nuova == null or not run.remove_card(vecchia):
			return null
		run.add_card(nuova)
		ctx["log"].append(tr("%s se ne va, arriva %s")
			% [tr(vecchia.display_name), tr(nuova.display_name)])
		return null
	)

	resolver.register("run_remove_card", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		if run == null:
			return null
		for i in maxi(int(roundf(resolver.value(effect, "amount", ctx, 1.0))), 1):
			var pool := run.collection
			if pool.is_empty() or not run.can_remove():
				break
			var victim: Card = _rng.pick(pool)
			if run.remove_card(victim):
				ctx["log"].append(tr("esce dal mazzo: %s") % tr(victim.display_name))
		return null
	)

	## Posa un sigillo su una carta a caso del mazzo. Le carte già piene vengono
	## saltate: meglio niente che un acquisto che sparisce nel nulla.
	resolver.register("run_seal", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		var seal_id := String(effect.get("seal", ""))
		if run == null or not Content.has("seals", seal_id):
			return null

		var candidates: Array[Card] = []
		for card in run.collection:
			if card.seals.size() < Card.MAX_SEALS:
				candidates.append(card)
		if candidates.is_empty():
			return null

		var chosen: Card = _rng.pick(candidates)
		var seal := Content.entry("seals", seal_id)
		if chosen.add_seal(seal):
			ctx["log"].append(tr("%s prende il sigillo %s")
				% [tr(chosen.display_name), tr(String(seal.get("name", seal_id)))])
		return null
	)

	## Un bonus che vale per tutta la run: si applica al mazzo a ogni battaglia.
	resolver.register("run_passive", func(effect: Dictionary, ctx: Dictionary) -> Variant:
		var run: RunState = ctx.get("run")
		if run == null:
			return null
		var rule: Dictionary = effect.get("rule", {})
		if rule.is_empty():
			return null
		run.passives.append(rule.duplicate(true))
		ctx["log"].append(String(effect.get("text", "hai imparato qualcosa")))
		return null
	)
