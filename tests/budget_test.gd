extends TestCase
## Il bilanciamento del catalogo, misurato invece che discusso.
##
## Non esiste una banda assoluta di "punti al secondo" giusta per tutti: una
## carta alta rende più di una bassa, ed è esattamente ciò che la rende costosa.
## Quello che deve restare vero è più sottile, e più utile:
##
##   1. a parità di valore i semi si equivalgono, o se ne compra uno solo
##   2. dentro un seme la curva sale col valore, o le carte alte sono una truffa
##   3. le carte con carattere sono un premio, non un altro gioco
##   4. le famiglie rendono uguale: la differenza sta nel ritmo, non nella forza
##
## Finché questi quattro restano verdi dopo aver toccato `suits.json` o
## `ranks.json`, il catalogo è ancora sano. *Quale* carta è fuori riga lo dice
## `tools/diagnosi_carte.gd`, che usa lo stesso metro (`game/logic/budget.gd`).

## Quanto può rendere la carta migliore rispetto alla peggiore, a parità di
## valore e famiglia. Sopra questo, un seme smette di essere una scelta.
const SPREAD_MASSIMO := 1.7

## Quanto può aggiungere una carta con carattere sopra la carta nuda di pari
## seme e valore. Sopra questo non è più una figura, è una carta di un altro
## gioco finita nel mazzo sbagliato.
const PREMIO_MASSIMO := 1.8

## Di quanto possono divergere le medie di due famiglie.
const SCARTO_FRA_FAMIGLIE := 0.25

## Quanto può rendere, al massimo, una carta comprabile. Gli altri tre test
## confrontano carte fra loro — a parità di valore, dentro un seme, contro la
## versione nuda — e una carta che è **sola** nel suo seme non viene confrontata
## con nessuno: il Jolly, il Pesca Quattro, L'antigh passerebbero indenni. Questo
## è il numero che li prende.
const TETTO := 3.4

## Sotto questo valore le carte sono troppo piccole perché il rapporto significhi
## qualcosa: un asso rende poco per costruzione, non per errore.
const VALORE_MINIMO_CONFRONTABILE := 3


## La carta senza la sua voce in specials.json: serve a misurare il seme, non il
## carattere. `CardLibrary.build_from` attacca sempre la special.
## Null se quel seme e quel valore non fanno una carta (le carte fuori seme si
## tengono il proprio valore per sé).
func _nuda(suit_id: String, rank_id: String) -> Card:
	var suit := Content.entry("suits", suit_id)
	var rank := Content.entry("ranks", rank_id)
	if not CardLibrary.is_valid_pair(suit, rank):
		return null
	return Card.new(suit, rank)


func _al_secondo(card: Card) -> float:
	return CardBudget.punti_al_secondo(card)


## I semi comprabili, raggruppati per famiglia. Fuori restano i mazzi ancora
## senza effetti e le carte che si ottengono solo in battaglia: misurarli
## insieme agli altri sposterebbe ogni media senza dire niente di vero.
func _semi_per_famiglia() -> Dictionary:
	var out: Dictionary = {}
	for family in CardLibrary.pool_families():
		var id := String(family.get("id", ""))
		var semi := CardLibrary.suits_of(id, true)
		if not semi.is_empty():
			out[id] = semi
	return out


func _valori_di(famiglia: String) -> Array:
	var out := CardLibrary.ranks_of(famiglia, 1, 99, true)
	out.sort_custom(func(a, b): return int(a.get("value", 0)) < int(b.get("value", 0)))
	return out


func test_a_parita_di_valore_i_semi_si_equivalgono() -> void:
	for famiglia in _semi_per_famiglia():
		var semi: Array = _semi_per_famiglia()[famiglia]
		for rank in _valori_di(famiglia):
			if int(rank.get("value", 0)) < VALORE_MINIMO_CONFRONTABILE:
				continue

			var minimo := INF
			var massimo := 0.0
			var peggiore := ""
			var migliore := ""
			for suit in semi:
				var card := _nuda(String(suit["id"]), String(rank["id"]))
				if card == null:
					continue
				var resa := _al_secondo(card)
				if resa < minimo:
					minimo = resa
					peggiore = String(suit["name"])
				if resa > massimo:
					massimo = resa
					migliore = String(suit["name"])

			if minimo <= 0.0:
				fail("%s di %s non rende niente" % [rank.get("name"), peggiore])
				continue
			assert_lt(massimo / minimo, SPREAD_MASSIMO,
				"al valore %s (%s): %s rende %.2f e %s solo %.2f — uno dei due non si compra"
				% [rank.get("value"), famiglia, migliore, massimo, peggiore, minimo])


func test_dentro_un_seme_la_curva_sale_col_valore() -> void:
	for famiglia in _semi_per_famiglia():
		for suit in _semi_per_famiglia()[famiglia]:
			var precedente := 0.0
			var nome_precedente := ""
			for rank in _valori_di(famiglia):
				var card := _nuda(String(suit["id"]), String(rank["id"]))
				if card == null:
					continue
				var resa := _al_secondo(card)
				if not nome_precedente.is_empty():
					assert_gt(resa, precedente - 0.001,
						"%s: il %s rende %.2f, meno del %s (%.2f) — comprare più alto peggiora"
						% [suit.get("name"), rank.get("name"), resa, nome_precedente, precedente])
				precedente = resa
				nome_precedente = String(rank.get("name", ""))


func test_le_carte_con_carattere_sono_un_premio_non_un_altro_gioco() -> void:
	for special in Content.list("specials"):
		var parti := String(special.get("id", "")).split("_", false, 1)
		if parti.size() != 2:
			continue

		if not Content.has("suits", parti[0]) or not Content.has("ranks", parti[1]):
			continue
		var intera := CardLibrary.build_from(parti[0], parti[1])
		var nuda := _nuda(parti[0], parti[1])
		if intera == null or nuda == null:
			continue

		var base := _al_secondo(nuda)
		if base <= 0.0:
			continue
		assert_lt(_al_secondo(intera) / base, PREMIO_MASSIMO,
			"%s rende %.2f contro %.2f della carta nuda: non è una figura, è un'altra carta"
			% [special.get("name"), _al_secondo(intera), base])


## Quanto rende, in media, quella famiglia alle carte di quel valore. Zero se a
## quel valore non ha carte.
func _resa_al_valore(famiglia: String, valore: int) -> float:
	var somma := 0.0
	var quante := 0
	for suit in CardLibrary.suits_of(famiglia, true):
		for rank in _valori_di(famiglia):
			if int(rank.get("value", 0)) != valore:
				continue
			var card := _nuda(String(suit["id"]), String(rank["id"]))
			if card != null:
				somma += _al_secondo(card)
				quante += 1
	return somma / quante if quante > 0 else 0.0


func test_le_famiglie_rendono_uguale() -> void:
	# Il confronto va fatto **a parità di valore**, non sulla media di tutto: un
	# mazzo che parte dal quattro sembrerebbe più forte di uno che parte
	# dall'asso solo perché non ha carte piccole. Le famiglie che non hanno
	# nessun valore in comune non si confrontano.
	var famiglie: Array = _semi_per_famiglia().keys()
	assert_gt(famiglie.size(), 1, "serve più di una famiglia per confrontarle")

	var confronti := 0
	for i in famiglie.size():
		for j in range(i + 1, famiglie.size()):
			var somma_a := 0.0
			var somma_b := 0.0
			var comuni := 0
			for rank in _valori_di(String(famiglie[i])):
				var valore := int(rank.get("value", 0))
				if valore < VALORE_MINIMO_CONFRONTABILE:
					continue
				# **Tutte e due** devono avere carte a quel valore. Un valore che
				# una delle due non copre non è un confronto: è uno zero che
				# tira giù la media di chi non c'era. Succede per davvero — i
				# Gaiofanamon hanno un valore che esiste solo per L'antigh, e
				# L'antigh in bottega non ci va.
				var a := _resa_al_valore(String(famiglie[i]), valore)
				var b := _resa_al_valore(String(famiglie[j]), valore)
				if a <= 0.0 or b <= 0.0:
					continue
				somma_a += a
				somma_b += b
				comuni += 1

			if comuni == 0:
				continue
			confronti += 1
			var media_a := somma_a / comuni
			var media_b := somma_b / comuni
			assert_lt(absf(media_a - media_b) / maxf(media_a, media_b), SCARTO_FRA_FAMIGLIE,
				"sui %d valori in comune %s rende %.2f e %s %.2f: la differenza fra le famiglie deve stare nel ritmo, non nella forza"
				% [comuni, famiglie[i], media_a, famiglie[j], media_b])

	assert_gt(confronti, 0, "nessuna coppia di famiglie condivide un valore: non si sta confrontando niente")


func test_nessuna_carta_sfonda_il_tetto() -> void:
	for card_id in CardLibrary.pool_ids():
		var card := CardLibrary.build(card_id)
		if card == null:
			continue
		assert_lt(_al_secondo(card), TETTO,
			"%s rende %.2f al secondo: sopra il tetto non è una carta forte, è la sola che si compra"
			% [card.display_name, _al_secondo(card)])
