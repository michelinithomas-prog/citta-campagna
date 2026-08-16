extends TestCase
## L'integrità dei dati. In jam si aggiungono righe di JSON di corsa: questi
## test prendono gli errori che altrimenti si scoprirebbero davanti al pubblico,
## e li prendono in due secondi.


func test_i_json_si_caricano_tutti_senza_errori() -> void:
	# Prende in un colpo solo i file malformati e gli id duplicati.
	assert_eq(Content.errors().size(), 0, "Content: %s" % [Content.errors()])


func test_ci_sono_tutte_le_collezioni_che_servono() -> void:
	for name in ["families", "suits", "ranks", "specials", "seals", "events", "opponents"]:
		assert_gt(Content.count(name), 0, "collezione vuota o mancante: %s" % name)


func test_il_tuning_ha_le_chiavi_che_il_gioco_legge() -> void:
	for path in [
		"player.hp", "player.lives", "player.board_size",
		"deck.starting", "deck.min_size",
		"battle.tick", "shop.card_offers", "shop.card_cost", "shop.remove_cost",
		"menu.best_stat",
	]:
		assert_true(Cfg.has(path), "tuning.json: manca %s" % path)


# --- carte ---------------------------------------------------------------

func test_ogni_carta_speciale_esiste_davvero() -> void:
	for entry in Content.list("specials"):
		var id := String(entry.get("id", ""))
		assert_not_null(CardLibrary.build(id), "specials.json cita una carta inesistente: %s" % id)


func test_le_carte_speciali_hanno_un_effetto_o_un_testo() -> void:
	for entry in Content.list("specials"):
		var id := String(entry.get("id", ""))
		var effects: Array = entry.get("effects", [])
		assert_false(effects.is_empty() and not entry.has("text"),
			"%s non aggiunge niente e non spiega niente" % id)


func test_una_carta_speciale_porta_il_suo_effetto_in_piu() -> void:
	# Il Re di Picche fa quello che fanno le picche, più il suo.
	var re := CardLibrary.build("picche_c13")
	var normale := CardLibrary.build("picche_c10")
	assert_gt(re.effects.size(), normale.effects.size())


# --- avversari -----------------------------------------------------------

func test_ogni_avversario_e_giocabile() -> void:
	var slots := Cfg.get_int("player.board_size", 5)
	for entry in Content.list("opponents"):
		var id := String(entry.get("id", ""))
		assert_gt(int(entry.get("hp", 0)), 0, "%s non ha vita" % id)
		# Con un mazzo pari agli slot il deck-out arriva alla prima attivazione:
		# non è un avversario, è un forfait.
		assert_gt(int(entry.get("deck_size", 0)), slots + 2,
			"%s ha troppe poche carte per essere un avversario" % id)


func test_ogni_avversario_produce_il_mazzo_che_promette() -> void:
	for entry in Content.list("opponents"):
		var deck := CardLibrary.generate(RngStream.new(4), entry)
		assert_eq(deck.size(), int(entry.get("deck_size", 0)),
			"%s: mazzo generato della misura sbagliata" % entry.get("id"))


func test_il_numero_di_avversari_e_la_lunghezza_della_run() -> void:
	assert_gt(Content.count("opponents"), 3, "una run di tre round non è una run")


# --- coerenza fra semi e valori -----------------------------------------

func test_ogni_seme_appartiene_a_una_famiglia_che_ha_dei_valori() -> void:
	for suit in Content.list("suits"):
		var family := String(suit.get("family", ""))
		assert_gt(CardLibrary.ranks_of(family).size(), 0,
			"il seme %s è di una famiglia senza valori: %s" % [suit.get("id"), family])


func test_il_metro_del_veleno_e_quello_del_gioco_dicono_la_stessa_cosa() -> void:
	# Due numeri uguali scritti in due posti divergono. Questo li tiene legati.
	assert_almost(CardBudget.VELENO_OGNI, Cfg.get_float("battle.poison_every", 3.0), 0.001,
		"budget.gd valuta il veleno con un passo diverso da quello che il gioco usa davvero")


func test_ogni_famiglia_nominata_esiste_davvero() -> void:
	# Una famiglia scritta storta in suits.json non esplode: le carte semplicemente
	# non compaiono più in bottega, ed è il tipo di errore che si scopre giocando.
	for collection in ["suits", "ranks"]:
		for entry in Content.list(collection):
			var family := String(entry.get("family", ""))
			assert_true(Content.has("families", family),
				'%s "%s": la famiglia "%s" non è in families.json' % [collection, entry.get("id"), family])


func test_ogni_famiglia_ha_nome_colore_e_moltiplicatore() -> void:
	for family in Content.list("families"):
		var id := String(family.get("id", ""))
		assert_false(String(family.get("name", "")).is_empty(), "%s: manca il nome" % id)
		assert_has(CardView.COLORS, String(family.get("color", "")),
			'%s: il colore "%s" non è fra quelli che CardView sa disegnare' % [id, family.get("color")])
		assert_gt(float(family.get("price_multiplier", 0.0)), 0.0,
			"%s: senza price_multiplier le sue carte sarebbero gratis" % id)


func test_ogni_famiglia_del_pool_ha_semi_e_valori_comprabili() -> void:
	for family in CardLibrary.pool_families():
		var id := String(family.get("id", ""))
		assert_gt(CardLibrary.suits_of(id, true).size(), 0,
			"%s è nel pool ma non ha semi comprabili" % id)
		assert_gt(CardLibrary.ranks_of(id, 1, 99, true).size(), 0,
			"%s è nel pool ma non ha valori comprabili" % id)


func test_i_glifi_dei_semi_sono_scritti() -> void:
	for suit in Content.list("suits"):
		assert_false(String(suit.get("symbol", "")).is_empty(),
			"il seme %s non ha simbolo" % suit.get("id"))


# --- disegni -------------------------------------------------------------

## Le cartelle dei disegni si chiamano come la famiglia, perché è così che
## `CarteArt` le cerca. Ribattezzare una famiglia nei JSON e lasciare indietro la
## cartella toglie il disegno a tutte le sue carte **in silenzio**: `per_carta()`
## restituisce null, chi chiama regge il caso, e il gioco continua a girare con
## un mazzo di rettangoli scritti. È successo con "porkemon" → "gaiofanamon".
func test_ogni_cartella_di_disegni_e_di_una_famiglia_che_esiste() -> void:
	var cartelle := DirAccess.get_directories_at(CarteArt.CARTELLA)
	for cartella in cartelle:
		assert_true(Content.has("families", cartella),
			'art/carte/%s: nessuna famiglia si chiama così — o la cartella va rinominata, o la famiglia' % cartella)


## Le carte che possono restare scritte invece che illustrate. **Oggi è vuota**,
## e va tenuta vuota: ogni carta del gioco ha il suo disegno.
##
## Chiedere "almeno un disegno per famiglia" non bastava: i gaiofanamon ne
## trovavano due su quindici e il test passava contento, perché la regola dei
## nomi non parlava la stessa lingua dei file e nessuno lo diceva.
const SENZA_DISEGNO: Array[String] = []


## Ogni carta trova il suo disegno. **Aprire un buco è tutto il punto**: una
## carta bianca non dà nessun errore, `per_carta()` restituisce null e chi chiama
## regge il caso. Si scopre allo stand.
func test_le_carte_trovano_il_loro_disegno() -> void:
	CarteArt.dimentica()
	var famiglie_illustrate := DirAccess.get_directories_at(CarteArt.CARTELLA)
	for id in CardLibrary.all_ids():
		var card := CardLibrary.build(id)
		if card == null or not card.family in famiglie_illustrate:
			continue
		if CarteArt.per_carta(card) != null:
			continue
		assert_true(id in SENZA_DISEGNO,
			'%s ("%s") non trova nessun disegno — o manca il file, o il nome non è quello che cerca CarteArt' % [id, card.display_name])


## Un ritratto scritto storto non esplode: la cornice resta vuota e nessuno se ne
## accorge finché non ci si passa davanti. Vale per gli avversari e per gli
## incontri, che usano la stessa cartella.
func test_ogni_ritratto_citato_esiste_davvero() -> void:
	for collection in ["opponents", "events"]:
		for entry in Content.list(collection):
			for key in ["portrait", "image"]:
				var percorso := String(entry.get(key, ""))
				if percorso.is_empty():
					continue
				assert_true(ResourceLoader.exists(percorso),
					'%s "%s": il ritratto %s non c\'è' % [collection, entry.get("id"), percorso])


func test_ogni_avversario_ha_una_faccia_e_un_archetipo() -> void:
	for entry in Content.list("opponents"):
		var id := String(entry.get("id", ""))
		assert_true(entry.has("portrait"), "%s: senza ritratto è un nome e basta" % id)
		assert_true(entry.has("text"), "%s: senza una riga di presentazione non si capisce chi è" % id)
		var pesi: Dictionary = entry.get("weights", {})
		assert_gt(pesi.size(), 0, "%s: senza pesi non ha un archetipo, ha un mazzo a caso" % id)


func test_ci_sono_tanti_avversari_quante_vittorie_servono() -> void:
	# Dieci vittorie e nove avversari significherebbe rigiocare l'ultimo due
	# volte: l'ultima battaglia della run sarebbe un bis, non un finale.
	var stato := RunState.new(RngStream.new(1))
	assert_eq(Content.count("opponents"), stato.wins_needed(),
		"gli avversari devono bastare per tutte le vittorie che servono")


## Un'icona che manca non esplode: il bottone resta senza disegno e la vetrina
## sembra a metà. Con diciotto reliquie che si distinguono soprattutto a colpo
## d'occhio, è un difetto che si nota solo giocando.
func test_ogni_reliquia_comprabile_ha_la_sua_icona() -> void:
	ReliquieArt.dimentica()
	for relic in Content.list("relics"):
		if not bool(relic.get("in_shop", true)):
			continue  # i premi degli incontri non passano dalla vetrina
		assert_not_null(ReliquieArt.per_reliquia(relic),
			'reliquia "%s": manca %s/%s.png' % [relic.get("name"), ReliquieArt.CARTELLA, relic.get("id")])


## E il contrario: un'icona che non è di nessuno è un file rimasto indietro dopo
## un rename, e prima o poi qualcuno lo cerca chiedendosi perché non compare.
func test_ogni_icona_appartiene_a_una_reliquia() -> void:
	for file in DirAccess.get_files_at(ReliquieArt.CARTELLA):
		if not file.ends_with(".png"):
			continue
		var id := file.trim_suffix(".png")
		assert_true(Content.has("relics", id),
			'%s/%s: nessuna reliquia si chiama "%s"' % [ReliquieArt.CARTELLA, file, id])
