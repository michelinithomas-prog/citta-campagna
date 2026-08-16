extends TestCase
## Gli effetti che toccano la plancia avversaria: bruciare, rallentare,
## affrettare, riciclare. Sono quelli che rendono il duello uno scontro invece
## di due solitari in parallelo.

var duel: Duel


func after_each() -> void:
	if duel != null:
		duel.resolver.clear_handlers()
		duel = null


func _deck(card_id: String, count: int) -> Array[Card]:
	var out: Array[Card] = []
	for i in count:
		out.append(CardLibrary.build(card_id))
	return out


## Un mazzo in cui la prima carta porta un sigillo: serve a far entrare in campo
## l'effetto da provare.
func _deck_with_seal(card_id: String, count: int, seal_id: String, sealed_count: int = 1) -> Array[Card]:
	var out := _deck(card_id, count)
	for i in mini(sealed_count, out.size()):
		out[i].add_seal(Content.entry("seals", seal_id))
	return out


func _side(name_text: String, cards: Array[Card], config: Dictionary = {}) -> Side:
	return Side.new(name_text, cards, RngStream.new(7), config)


# --- burn ----------------------------------------------------------------

func test_bruciare_scarta_la_carta_senza_farla_partire() -> void:
	# Chi brucia porta solo carte scudo, così l'unico modo che ha la vittima di
	# perdere HP sarebbe... nessuno. Se una carta bruciata partisse davvero, si
	# vedrebbe: le sue sono tutte spade, e le spade fanno male.
	var attaccante := _side("io", _deck_with_seal("fiori_c1", 30, "tarlo", 30),
		{"hp": 200, "is_player": true})
	var vittima := _side("lui", _deck("spade_r10", 30), {"hp": 100})
	duel = Duel.new(attaccante, vittima, RngStream.new(7), 0.05)

	var bruciate := [0]
	duel.card_burned.connect(func(_s: Side, _slot: int, _c: Card) -> void: bruciate[0] += 1)

	# Quindici secondi: le spade da 11 secondi avrebbero avuto tutto il tempo di
	# partire, se solo qualcuno non le togliesse dal tavolo un attimo prima.
	duel.clock.advance_seconds(15.0)

	assert_gt(bruciate[0], 10, "il tarlo deve bruciare a ogni attivazione")
	assert_eq(attaccante.hp, 200, "nessuna spada deve essere riuscita a partire")
	assert_eq(vittima.pile.discarded(), bruciate[0], "ogni carta bruciata finisce negli scarti")


func test_bruciare_accelera_il_deckout_avversario() -> void:
	# Due lati identici, ma uno brucia. A parità di tutto il resto deve vincere,
	# e deve vincere per esaurimento del mazzo altrui.
	var attaccante := _side("io", _deck_with_seal("cuori_c3", 12, "tarlo", 12),
		{"hp": 300, "is_player": true})
	var vittima := _side("lui", _deck("cuori_c3", 12), {"hp": 300})
	duel = Duel.new(attaccante, vittima, RngStream.new(7), 0.05)
	duel.simulate_to_end()

	assert_true(duel.won, "chi brucia deve arrivare primo")
	assert_eq(duel.reason, Side.REASON_DECKOUT)


func test_bruciare_a_mazzo_vuoto_manda_ko() -> void:
	# La vittima ha esattamente cinque carte: la plancia è piena e la pila è
	# vuota. La prima bruciatura non trova rimpiazzo.
	var attaccante := _side("io", _deck_with_seal("picche_c1", 40, "tarlo", 40),
		{"hp": 300, "is_player": true})
	var vittima := _side("lui", _deck("coppe_r10", 5), {"hp": 300})
	duel = Duel.new(attaccante, vittima, RngStream.new(7), 0.05)
	duel.simulate_to_end()

	assert_true(duel.won)
	assert_eq(duel.reason, Side.REASON_DECKOUT)


# --- slow / haste --------------------------------------------------------

func test_rallentare_allunga_l_attesa_avversaria() -> void:
	var attaccante := _side("io", _deck_with_seal("picche_c1", 30, "melassa", 30),
		{"hp": 300, "is_player": true})
	var vittima := _side("lui", _deck("spade_r10", 30), {"hp": 300})
	duel = Duel.new(attaccante, vittima, RngStream.new(7), 0.05)

	var prima: float = vittima.board[0].cooldown
	duel.clock.advance_seconds(2.5)  # la melassa parte a 2.3s, la vittima a 10.5s
	assert_gt(vittima.board[0].cooldown, prima - 2.5, "il rallentamento deve aver spostato l'attesa in avanti")


func test_affrettare_accorcia_le_proprie_attese_senza_incatenarsi() -> void:
	# Uno sprone gigantesco su cinque carte: se l'effetto risolvesse a catena
	# questo test entrerebbe in ricorsione invece di terminare.
	var cards := _deck("spade_r10", 30)
	for i in 5:
		cards[i].add_seal({"id": "supersprone", "extra_effects": [{"type": "haste", "amount": 999.0}]})
	var attaccante := _side("io", cards, {"hp": 300, "is_player": true})
	var vittima := _side("lui", _deck("cuori_c1", 60), {"hp": 300})
	duel = Duel.new(attaccante, vittima, RngStream.new(7), 0.05)

	duel.clock.advance_seconds(11.0)
	assert_gt(duel.activations, 5, "lo sprone deve aver anticipato le altre carte")
	assert_false(duel.is_over and duel.reason == "tempo", "non deve essere finita per timeout")


# --- recycle -------------------------------------------------------------

func test_una_carta_con_eco_torna_nel_mazzo() -> void:
	# Eco vale due volte: la carta sigillata non finisce negli scarti finché non
	# ha esaurito i suoi due rientri.
	var cards := _deck("cuori_c1", 6)
	cards[0].add_seal(Content.entry("seals", "eco"))
	var mine := _side("io", cards, {"hp": 300, "is_player": true})
	var theirs := _side("lui", _deck("cuori_c1", 60), {"hp": 300})
	duel = Duel.new(mine, theirs, RngStream.new(7), 0.05)
	duel.simulate_to_end()

	# Sei carte senza eco reggono 2 attivazioni prima del deck-out; con due
	# rientri gratis se ne fanno di più.
	assert_gt(mine.pile.discarded() + mine.board.size(), 6 - 3,
		"la carta riciclata non deve sparire negli scarti al primo giro")
	assert_eq(duel.reason, Side.REASON_DECKOUT)


## Quante volte riesce a giocare una carta, con questo mazzo, prima di restare a
## secco. Le carte hanno tutte lo stesso cooldown, quindi il tempo trascorso non
## distingue niente: partono a ondate. Il numero di attivazioni sì.
func _attivazioni_prima_del_deckout(cards: Array[Card]) -> int:
	var mine := _side("io", cards, {"hp": 300, "is_player": true})
	var theirs := _side("lui", _deck("cuori_c1", 400), {"hp": 300})
	var d := Duel.new(mine, theirs, RngStream.new(7), 0.05)

	var conteggio := [0]
	d.card_activated.connect(func(side: Side, _slot: int, _c: Card) -> void:
		if side.is_player:
			conteggio[0] += 1
	)
	d.simulate_to_end()
	d.resolver.clear_handlers()
	return conteggio[0]


func test_eco_regala_altri_giri_prima_del_deckout() -> void:
	var senza := _attivazioni_prima_del_deckout(_deck("cuori_c1", 8))
	var con := _attivazioni_prima_del_deckout(_deck_with_seal("cuori_c1", 8, "eco", 3))
	# Tre carte con Eco valgono due rientri l'una: sei carte di mazzo in più.
	assert_gt(con, senza, "l'eco deve regalare altre giocate prima del deck-out")


# --- integrità -----------------------------------------------------------

## Dove possono stare gli effetti, dentro una voce di un JSON.
const CONTENITORI := ["effects", "extra_effects"]

## Le collezioni che contengono effetti di battaglia. `ranks` c'è perché il tema
## del numero vive lì: senza, un tipo sbagliato in ranks.json non farebbe niente
## e nessuno se ne accorgerebbe.
const COLLEZIONI := ["suits", "ranks", "specials", "seals"]

## Tutto quello che una riga di effetto può contenere. Una chiave fuori da qui è
## quasi sempre un refuso — e un refuso in un effetto non dà nessun segnale:
## la carta semplicemente non fa quella cosa, per tutta la jam.
const CHIAVI_AMMESSE := [
	# l'effetto
	"type", "amount", "text",
	# i meta
	"times", "p", "effect", "else", "effects", "weights",
	# i modificatori ortogonali
	"target", "pierce", "when", "all", "slots", "buff", "card", "cards", "where",
	# i valori dinamici
	"stat", "of", "scale", "add", "random",
]


## Scorre un albero di effetti, meta compresi: un `chance` che avvolge un tipo
## inesistente è invisibile se ci si ferma al primo livello.
func _ogni_effetto(effect: Variant, out: Array) -> void:
	if not effect is Dictionary:
		return
	var dict: Dictionary = effect
	out.append(dict)
	for key in ["effect", "else"]:
		if dict.has(key):
			_ogni_effetto(dict[key], out)
	for nested in dict.get("effects", []):
		_ogni_effetto(nested, out)


func _tutti_gli_effetti_dei_dati() -> Array:
	var out: Array = []
	for collection in COLLEZIONI:
		for entry in Content.list(collection):
			for key in CONTENITORI:
				for effect in entry.get(key, []):
					var trovati: Array = []
					_ogni_effetto(effect, trovati)
					for dict in trovati:
						out.append({"dove": "%s \"%s\"" % [collection, entry.get("id", "?")], "effetto": dict})
	return out


func test_ogni_effetto_dei_dati_ha_un_handler() -> void:
	# La rete che impedisce a una riga di JSON scritta in jam di non fare niente
	# in silenzio: EffectResolver ignora i tipi sconosciuti con un warning.
	duel = Duel.new(
		_side("a", _deck("picche_c1", 6), {"is_player": true}),
		_side("b", _deck("picche_c1", 6)),
		RngStream.new(1), 0.05
	)
	for voce in _tutti_gli_effetti_dei_dati():
		var type := String((voce["effetto"] as Dictionary).get("type", ""))
		assert_true(duel.resolver.has_handler(type),
			'%s: nessun handler per "%s"' % [voce["dove"], type])


func test_nessun_effetto_ha_chiavi_che_nessuno_legge() -> void:
	for voce in _tutti_gli_effetti_dei_dati():
		for key in (voce["effetto"] as Dictionary):
			assert_true(String(key) in CHIAVI_AMMESSE,
				'%s: la chiave "%s" non la legge nessuno — refuso?' % [voce["dove"], key])
