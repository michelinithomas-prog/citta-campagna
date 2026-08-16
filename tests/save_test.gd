extends TestCase
## Il salvataggio della partita in corso: quello che tiene in piedi "Continua".
##
## Il punto delicato non è scrivere il JSON, è **non ricalcolare niente al
## ripristino**. Le reliquie una tantum (vita massima, vite, carte) hanno già
## versato il loro effetto quando sono state comprate: se il caricamento le
## riapplicasse, bastarebbe riaprire il gioco tre volte per avere trentasei
## punti di vita in più e sei carte regalate. Per questo qui si carica tre volte
## di fila e si controlla che i numeri non si muovano.

var run: RunState

## Quello che c'era nel salvataggio prima che questa suite ci mettesse le mani.
var _partita_vera: Variant = null


func before_each() -> void:
	# Questi test scrivono su user://save.json, lo stesso file della partita
	# vera. Si mette da parte quello che c'era e si rimette alla fine: eseguire
	# la suite non deve far sparire la run di chi stava giocando — è successo, e
	# dal menu "Continua" si era spento senza spiegazioni.
	_partita_vera = Save.get_value(RunState.SAVE_KEY, null)
	RunState.clear_save()
	run = RunState.new(RngStream.new(11))


func after_each() -> void:
	RunState.clear_save()
	if _partita_vera != null:
		Save.set_value(RunState.SAVE_KEY, _partita_vera)
		Save.flush()
	run = null


# --- attrezzi ------------------------------------------------------------

## Una reliquia dai JSON scelta per quello che fa, non per il suo id: i
## contenuti si ritoccano di continuo in jam, i test non devono seguirli.
func _reliquia_con(chiave: String) -> Dictionary:
	for relic in Content.list("relics"):
		if (relic as Dictionary).has(chiave):
			return (relic as Dictionary).duplicate(true)
	return {}


func _sigillo_con(chiave: String) -> Dictionary:
	for seal in Content.list("seals"):
		if (seal as Dictionary).has(chiave):
			return (seal as Dictionary).duplicate(true)
	return {}


func _relic_ids(r: RunState) -> Array[String]:
	var out: Array[String] = []
	for relic in r.relics:
		out.append(String(relic.get("id", "")))
	return out


## Tutto quello che di una run il giocatore vede davvero, in una stringa sola:
## i numeri della run più il mazzo che scende in campo, coi passivi già
## applicati. Due run con la stessa impronta sono la stessa run.
## È una stringa e non un confronto campo per campo perché il salvataggio passa
## da JSON, e da JSON i 2 tornano 2.0: qui i numeri sono già formattati.
func _impronta(r: RunState) -> String:
	var parts: Array[String] = []
	parts.append("round=%d vite=%d hp=%d oro=%d vittoria=%s" % [
		r.round_number, r.lives, r.max_hp, r.gold(), str(r.victory)
	])
	for card in r.battle_deck():
		parts.append("%s [%s] valore=%d attesa=%.3f · %s" % [
			card.id, ",".join(card.seal_ids()), card.value(), card.interval(), card.effect_text()
		])
	parts.append("reliquie=%s" % ",".join(_relic_ids(r)))
	parts.append("passivi=%d" % r.passives.size())
	return "\n".join(parts)


## Una run vissuta: sigilli addosso alle carte, reliquie in tasca, un passivo
## preso a un evento, oro e vite fuori dai valori di partenza.
func _run_vissuta() -> RunState:
	var r := RunState.new(RngStream.new(7))
	# Una run al quarto round il tutorial l'ha già passato: lasciarlo acceso
	# farebbe assorbire da lui la prima battaglia che il test gioca dopo.
	r.tutorial = false
	r.round_number = 4
	r.lives = 3
	r.max_hp = 61
	r.victory = false
	r.wallet.set_amount(RunState.GOLD, 23.0)

	r.collection[0].add_seal(_sigillo_con("value_mult"))
	r.collection[1].add_seal(_sigillo_con("cooldown_mult"))
	r.collection[1].add_seal(_sigillo_con("extra_effects"))
	r.add_card(CardLibrary.random_card(RngStream.new(9), {"poker": 1.0, "briscola": 1.0}, [1, 10]))

	r.relics.append(_reliquia_con("board_add"))
	r.relics.append(_reliquia_con("price_mult"))
	r.passives.append({"family": "briscola", "value_add": 2})
	return r


# --- una carta -----------------------------------------------------------

func test_una_carta_si_salva_come_seme_valore_e_sigilli() -> void:
	var card := run.collection[0]
	card.add_seal(_sigillo_con("value_mult"))

	var data := card.to_dict()
	assert_eq(data["suit"], card.suit_id)
	assert_eq(data["rank"], card.rank_id)
	assert_eq((data["seals"] as Array).size(), 1)
	assert_false(data.has("effects"), "gli effetti si rideducono dai JSON, non si congelano")


func test_una_carta_torna_identica() -> void:
	var card := run.collection[1]
	card.add_seal(_sigillo_con("value_mult"))
	card.add_seal(_sigillo_con("cooldown_mult"))

	var copia := Card.from_dict(card.to_dict())
	assert_not_null(copia)
	assert_eq(copia.id, card.id)
	assert_eq(copia.seal_ids(), card.seal_ids())
	assert_eq(copia.value(), card.value())
	assert_almost(copia.interval(), card.interval(), 0.0001)
	assert_eq(copia.effect_text(), card.effect_text())


func test_una_carta_che_non_esiste_piu_non_esplode() -> void:
	# Un salvataggio fatto prima che qualcuno togliesse un seme da suits.json.
	assert_null(Card.from_dict({"suit": "semequenoncesta", "rank": "c7", "seals": []}))
	assert_null(Card.from_dict({}))


# --- andata e ritorno ----------------------------------------------------

func test_la_run_torna_identica() -> void:
	var originale := _run_vissuta()
	var ripristinata := RunState.from_dict(originale.to_dict(), RngStream.new(7))

	assert_eq(ripristinata.round_number, originale.round_number)
	assert_eq(ripristinata.lives, originale.lives)
	assert_eq(ripristinata.max_hp, originale.max_hp)
	assert_eq(ripristinata.gold(), originale.gold())
	assert_eq(ripristinata.victory, originale.victory)
	assert_eq(ripristinata.deck_size(), originale.deck_size())
	assert_eq(_relic_ids(ripristinata), _relic_ids(originale))
	assert_eq(ripristinata.passives.size(), originale.passives.size())
	assert_eq(ripristinata.board_bonus(), originale.board_bonus())
	assert_almost(ripristinata.price_multiplier(), originale.price_multiplier(), 0.0001)
	assert_eq(_impronta(ripristinata), _impronta(originale))


func test_la_run_torna_identica_anche_passando_dal_disco() -> void:
	# Il giro vero: JSON su file e rilettura. Da lì i numeri tornano float, ed è
	# la strada su cui si rompono i confronti fatti con ==.
	var originale := _run_vissuta()
	var atteso := _impronta(originale)

	originale.save()
	Save.load_file()

	var ripristinata := RunState.load_saved(RngStream.new(7))
	assert_not_null(ripristinata, "il salvataggio non è tornato dal disco")
	assert_eq(_impronta(ripristinata), atteso)


func test_la_run_ripristinata_va_avanti_come_prima() -> void:
	var originale := _run_vissuta()
	var ripristinata := RunState.from_dict(originale.to_dict(), RngStream.new(7))

	assert_eq(ripristinata.opponent_for_round(), originale.opponent_for_round(),
		"il round ripristinato deve puntare allo stesso avversario")
	assert_true(ripristinata.finish_round(true))
	assert_eq(ripristinata.round_number, originale.round_number + 1)


# --- il punto in cui è facile sbagliare ----------------------------------

func test_le_reliquie_una_tantum_non_si_riapplicano() -> void:
	var rng := RngStream.new(3)
	assert_true(run.add_relic(_reliquia_con("max_hp_add"), rng))
	assert_true(run.add_relic(_reliquia_con("lives_add"), rng))
	assert_true(run.add_relic(_reliquia_con("cards_add"), rng))
	assert_true(run.add_relic(_reliquia_con("rule"), rng))

	var hp := run.max_hp
	var vite := run.lives
	var carte := run.deck_size()
	var passivi := run.passives.size()
	var reliquie := run.relics.size()
	assert_eq(passivi, 1, "la reliquia con `rule` deve aver messo un passivo solo")

	var corrente := run
	for giro in 3:
		corrente.save()
		Save.load_file()
		corrente = RunState.load_saved(RngStream.new(3))
		assert_not_null(corrente, "giro %d: niente da caricare" % [giro + 1])
		assert_eq(corrente.max_hp, hp, "giro %d: la vita massima è cresciuta da sola" % [giro + 1])
		assert_eq(corrente.lives, vite, "giro %d: le vite sono cresciute da sole" % [giro + 1])
		assert_eq(corrente.deck_size(), carte, "giro %d: il mazzo è cresciuto da solo" % [giro + 1])
		assert_eq(corrente.passives.size(), passivi, "giro %d: passivo duplicato" % [giro + 1])
		assert_eq(corrente.relics.size(), reliquie, "giro %d: reliquia duplicata" % [giro + 1])


func test_le_reliquie_ripristinate_valgono_ancora() -> void:
	# Non riapplicarle non vuol dire dimenticarle: quelle che si leggono a ogni
	# chiamata (plancia, oro, scudo, sconti) devono continuare a valere.
	var rng := RngStream.new(3)
	run.add_relic(_reliquia_con("board_add"), rng)
	run.add_relic(_reliquia_con("gold_per_round_add"), rng)
	run.add_relic(_reliquia_con("start_shield"), rng)
	run.add_relic(_reliquia_con("price_mult"), rng)

	var ripristinata := RunState.from_dict(run.to_dict(), RngStream.new(3))
	assert_eq(ripristinata.board_bonus(), run.board_bonus())
	assert_eq(ripristinata.extra_gold_per_round(), run.extra_gold_per_round())
	assert_eq(ripristinata.start_shield(), run.start_shield())
	assert_almost(ripristinata.price_multiplier(), run.price_multiplier(), 0.0001)
	for id in _relic_ids(run):
		assert_true(ripristinata.has_relic(id), "la reliquia %s è sparita" % id)


func test_i_sigilli_non_si_accumulano_a_ogni_caricamento() -> void:
	run.collection[0].add_seal(_sigillo_con("value_mult"))
	run.collection[0].add_seal(_sigillo_con("cooldown_mult"))
	var valore := run.collection[0].value()
	var attesa := run.collection[0].interval()

	var corrente := run
	for giro in 3:
		corrente.save()
		Save.load_file()
		corrente = RunState.load_saved(RngStream.new(11))
		assert_not_null(corrente, "giro %d: niente da caricare" % [giro + 1])
		assert_eq(corrente.collection[0].seals.size(), 2,
			"giro %d: i sigilli si sono moltiplicati" % [giro + 1])
		assert_eq(corrente.collection[0].value(), valore,
			"giro %d: il valore della carta sigillata è cresciuto" % [giro + 1])
		assert_almost(corrente.collection[0].interval(), attesa, 0.0001,
			"giro %d: l'attesa della carta sigillata è cambiata" % [giro + 1])


func test_i_passivi_degli_eventi_non_si_duplicano() -> void:
	run.passives.append({"family": "poker", "value_add": 3})
	run.passives.append({"suit": run.collection[0].suit_id, "cooldown_scale": 0.5})

	var corrente := run
	for giro in 3:
		corrente.save()
		Save.load_file()
		corrente = RunState.load_saved(RngStream.new(11))
		assert_eq(corrente.passives.size(), 2, "giro %d: passivi duplicati" % [giro + 1])

	# E devono ancora mordere sul mazzo, non essere solo contati.
	for i in run.collection.size():
		if run.collection[i].family == "poker":
			assert_eq(corrente.battle_deck()[i].value(), run.battle_deck()[i].value())


# --- niente da continuare ------------------------------------------------

func test_senza_salvataggio_non_si_continua() -> void:
	assert_false(RunState.has_saved())
	assert_null(RunState.load_saved(RngStream.new(1)),
		"senza partita in corso il menu non deve offrire Continua")


func test_clear_save_cancella_davvero() -> void:
	run.save()
	assert_true(RunState.has_saved())
	assert_not_null(RunState.load_saved(RngStream.new(1)))

	RunState.clear_save()
	assert_false(RunState.has_saved())
	assert_null(RunState.load_saved(RngStream.new(1)))

	# E non deve tornare dal disco alla riapertura del gioco.
	Save.load_file()
	assert_false(RunState.has_saved(), "il salvataggio cancellato è risorto dal file")
	assert_null(RunState.load_saved(RngStream.new(1)))


func test_salvare_di_nuovo_sovrascrive() -> void:
	run.save()
	run.earn(50)
	run.round_number = 6
	run.save()
	Save.load_file()

	var ripristinata := RunState.load_saved(RngStream.new(11))
	assert_not_null(ripristinata)
	assert_eq(ripristinata.gold(), run.gold(), "è tornato il salvataggio vecchio")
	assert_eq(ripristinata.round_number, 6)
