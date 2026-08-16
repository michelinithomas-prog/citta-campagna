extends TestCase
## Gli stati alterati: veleno, sanguinamento, paralisi, e le aure che lavorano
## mentre la carta aspetta.
##
## Le due curve opposte sono il cuore della faccenda e vanno difese:
## il sanguinamento è un colpo forte che si spegne da solo, il veleno è un
## fastidio che non finisce mai. Se diventassero la stessa cosa, due semi
## smetterebbero di essere due scelte.

var duel: Duel


func after_each() -> void:
	if duel != null:
		duel.resolver.clear_handlers()
		duel = null


## Un mazzo di carte che non fanno **niente** e ci mettono un minuto a non farlo.
## Non è una carta del gioco e non deve esserlo: ormai ogni seme e ogni valore
## portano un effetto, e per misurare un veleno serve un tavolo su cui non
## succeda nient'altro.
func _innocuo(count: int = 40) -> Array[Card]:
	var seme := {"id": "nulla", "name": "Nulla", "symbol": "·", "family": "poker",
		"color": "secondary", "cooldown": {"base": 60.0, "per_value": 0.0}, "effects": []}
	var valore := {"id": "n0", "family": "poker", "value": 1, "name": "Niente", "short": "-"}
	var out: Array[Card] = []
	for i in count:
		out.append(Card.new(seme, valore))
	return out


func _side(name_text: String, config: Dictionary = {}) -> Side:
	return Side.new(name_text, _innocuo(), RngStream.new(7), config)


func _duello(mine: Side, theirs: Side) -> Duel:
	duel = Duel.new(mine, theirs, RngStream.new(7), 0.05)
	return duel


## Ogni quanto morde il veleno. I test lo chiedono al gioco invece di scriverlo:
## il passo è una manopola di bilanciamento, e girarla non deve far diventare
## rossi dei test che parlano d'altro.
func _passo_veleno() -> float:
	return maxf(Cfg.get_float("battle.poison_every", 3.0), 0.1)


## Il tempo che serve a far mordere il veleno N volte, con un margine.
func _morsi(quanti: int) -> float:
	return _passo_veleno() * quanti + 0.1


# --- sanguinamento -------------------------------------------------------

func test_il_sanguinamento_cala_a_ogni_colpo_e_si_spegne() -> void:
	var vittima := _side("lui", {"hp": 100})
	_duello(_side("io", {"hp": 100, "is_player": true}), vittima)
	vittima.apply_bleed(3)

	duel.clock.advance_seconds(1.0)
	assert_eq(vittima.hp, 97, "primo secondo: tre danni")
	assert_eq(vittima.bleed, 2, "e il sanguinamento cala di uno")

	duel.clock.advance_seconds(1.0)
	assert_eq(vittima.hp, 95, "secondo secondo: due danni")

	duel.clock.advance_seconds(3.0)
	assert_eq(vittima.hp, 94, "terzo secondo: un danno, poi basta")
	assert_eq(vittima.bleed, 0, "il sanguinamento si esaurisce da solo")


func test_due_sanguinamenti_si_sommano() -> void:
	var vittima := _side("lui", {"hp": 100})
	_duello(_side("io", {"hp": 100, "is_player": true}), vittima)
	vittima.apply_bleed(2)
	vittima.apply_bleed(3)
	assert_eq(vittima.bleed, 5)

	duel.clock.advance_seconds(1.0)
	assert_eq(vittima.hp, 95, "cinque, non tre né due")


# --- veleno --------------------------------------------------------------

func test_il_veleno_non_cala_mai() -> void:
	var vittima := _side("lui", {"hp": 100})
	_duello(_side("io", {"hp": 100, "is_player": true}), vittima)
	vittima.apply_poison(2)

	duel.clock.advance_seconds(_morsi(5))
	assert_eq(vittima.hp, 90, "due danni per cinque morsi, sempre due")
	assert_eq(vittima.poison, 2, "il veleno resta quello che è")


func test_il_veleno_ha_un_tetto() -> void:
	# Senza soffitto un danno al secondo che non cala vale, in venti secondi,
	# venti volte il suo numero: due carte chiuderebbero la partita da sole.
	var tetto := maxi(Cfg.get_int("battle.poison_cap", 5), 1)
	var vittima := _side("lui", {"hp": 500})
	for i in tetto + 5:
		vittima.apply_poison(1)
	assert_eq(vittima.poison, tetto, "il veleno non deve poter salire all'infinito")


func test_ripulire_toglie_tutto_quello_che_rode() -> void:
	var vittima := _side("lui", {"hp": 100})
	_duello(_side("io", {"hp": 100, "is_player": true}), vittima)
	vittima.apply_bleed(4)
	vittima.apply_poison(3)

	assert_eq(vittima.cleanse(), 7, "restituisce quanto ha lavato via")
	duel.clock.advance_seconds(_morsi(5))
	assert_eq(vittima.hp, 100, "dopo un cleanse non deve arrivare più niente")


# --- lo scudo non c'entra ------------------------------------------------

func test_i_danni_nel_tempo_passano_attraverso_lo_scudo() -> void:
	# Se lo scudo li fermasse, un mazzo di Cuori sarebbe immune a due semi
	# interi e il veleno smetterebbe di essere una strategia.
	var vittima := _side("lui", {"hp": 100, "shield": 50})
	_duello(_side("io", {"hp": 100, "is_player": true}), vittima)
	vittima.apply_poison(3)

	duel.clock.advance_seconds(_morsi(2))
	assert_eq(vittima.hp, 94, "il veleno deve aver morso la vita, non lo scudo")
	assert_gt(vittima.shield(), 49, "e lo scudo non deve essersi consumato")


func test_il_colpo_che_buca_ignora_lo_scudo() -> void:
	var vittima := _side("lui", {"hp": 100, "shield": 20})
	assert_eq(vittima.take_damage(10, true), 10, "un colpo che buca arriva tutto")
	assert_eq(vittima.hp, 90)
	assert_eq(vittima.shield(), 20, "lo scudo non se ne accorge nemmeno")

	assert_eq(vittima.take_damage(10), 0, "un colpo normale invece lo consuma")
	assert_eq(vittima.hp, 90)
	assert_eq(vittima.shield(), 10)


func test_si_puo_morire_di_veleno() -> void:
	var vittima := _side("lui", {"hp": 4})
	var mine := _side("io", {"hp": 100, "is_player": true})
	_duello(mine, vittima)
	vittima.apply_poison(2)

	duel.clock.advance_seconds(_morsi(3))
	assert_true(duel.is_over, "il veleno deve poter chiudere la partita")
	assert_eq(duel.reason, Side.REASON_HP)
	assert_true(duel.won, "e a vincere è chi l'ha avvelenato")


func test_morire_insieme_di_veleno_e_un_pareggio() -> void:
	# Un solo _check_end() dopo entrambi i lati: se si controllasse dopo il
	# primo, a decidere chi muore sarebbe l'ordine in cui li scorriamo.
	var mine := _side("io", {"hp": 3, "is_player": true})
	var theirs := _side("lui", {"hp": 3})
	_duello(mine, theirs)
	mine.apply_poison(5)
	theirs.apply_poison(5)

	duel.clock.advance_seconds(_morsi(1))
	assert_true(duel.is_over)
	assert_eq(duel.reason, "pareggio", "caduti nello stesso istante")


# --- paralisi ------------------------------------------------------------

func test_una_carta_paralizzata_non_avanza() -> void:
	var vittima := _side("lui", {"hp": 100})
	_duello(_side("io", {"hp": 100, "is_player": true}), vittima)

	var prima: float = vittima.board[0].cooldown
	vittima.paralyze(2.0, 0)
	duel.clock.advance_seconds(1.0)
	assert_almost(vittima.board[0].cooldown, prima, 0.001, "il tempo per lei non passa")

	duel.clock.advance_seconds(2.0)
	assert_lt(vittima.board[0].cooldown, prima, "finita la paralisi riprende a scorrere")


func test_le_paralisi_non_si_sommano() -> void:
	# Due carte elettriche non devono poter congelare la plancia per sempre.
	var vittima := _side("lui", {"hp": 100})
	vittima.begin()
	vittima.paralyze(2.0)
	vittima.paralyze(3.0)
	vittima.paralyze(1.0)
	assert_almost(vittima.paralysis[0], 3.0, 0.001, "vale la più lunga, non la somma")


func test_la_paralisi_se_ne_va_con_la_carta() -> void:
	# È della creatura, non del posto: se la carta viene bruciata o rubata,
	# chi arriva dopo non deve trovare il ghiaccio di prima.
	var vittima := _side("lui", {"hp": 100})
	vittima.paralyze(5.0, 0)
	vittima.take_from(0)
	assert_almost(vittima.paralysis[0], 0.0, 0.001)


# --- aure ----------------------------------------------------------------

func test_un_effetto_a_tick_lavora_mentre_la_carta_aspetta() -> void:
	var cards := _innocuo(10)
	for card in cards:
		card.add_seal({"id": "aura", "extra_effects": [
			{"type": "heal", "amount": 2, "when": "tick"},
		]})
	assert_eq(cards[0].tick_effects.size(), 1, "l'effetto a tick va messo da parte")
	assert_true(cards[0].effects.filter(func(e): return e.get("when", "") == "tick").is_empty(),
		"e tolto da quelli dell'attivazione")

	var mine := Side.new("io", cards, RngStream.new(7), {"hp": 100, "is_player": true})
	_duello(mine, _side("lui", {"hp": 100}))
	mine.take_damage(30)
	var ferito := mine.hp

	duel.clock.advance_seconds(2.0)
	assert_gt(mine.hp, ferito, "l'aura deve curare mentre la carta sta ferma")


func test_gli_stati_non_consumano_casualita() -> void:
	# Se il tick tirasse anche un solo dado, ogni seed cambierebbe esito e i
	# test diventerebbero rossi senza che nessuno abbia toccato una regola.
	var esiti: Array = []
	for giro in 2:
		var mine := Side.new("io", _innocuo(12), RngStream.new(42), {"hp": 60, "is_player": true})
		var theirs := Side.new("lui", _innocuo(12), RngStream.new(42), {"hp": 60})
		var d := Duel.new(mine, theirs, RngStream.new(42), 0.05)
		mine.apply_poison(1)
		theirs.apply_bleed(4)
		d.simulate_to_end()
		esiti.append([d.won, d.reason, d.activations, mine.hp, theirs.hp, mine.poison, theirs.bleed])
		d.resolver.clear_handlers()
	assert_eq(esiti[0], esiti[1], "stesso seed, stesso duello, stati compresi")
