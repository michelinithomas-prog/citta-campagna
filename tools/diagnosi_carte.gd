extends SceneTree
## Stampa quanto rende ogni carta al secondo, dalla più forte alla più debole.
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/diagnosi_carte.gd
##
## È il gemello da riga di comando di `tests/budget_test.gd`: il test dice
## *quante* carte sono fuori banda, questo dice **quali** e di quanto. Con
## centocinquanta carte da tarare è la differenza fra un pomeriggio e una
## settimana.
##
## Da eseguire dopo ogni ritocco a `suits.json` o `ranks.json`, prima ancora di
## far girare la suite: gli errori di bilanciamento si vedono qui in due secondi.

var _content: Node
## Caricati a runtime, non per nome: le classi del gioco usano gli autoload, che
## non esistono ancora quando questo script viene compilato (è lui il MainLoop).
var _lib: GDScript
var _budget: GDScript


func _initialize() -> void:
	_content = root.get_node("Content")
	_lib = load("res://game/logic/card_library.gd")
	_budget = load("res://game/logic/budget.gd")


## Al primo frame, non in _initialize: lì Content è ancora vuoto.
func _process(_delta: float) -> bool:
	var righe: Array = []
	for card_id in _lib.pool_ids():
		var card = _lib.build(card_id)
		if card == null:
			continue
		righe.append({
			"id": card_id,
			"nome": card.display_name,
			"famiglia": card.family,
			"attesa": card.interval(),
			"punti": _budget.punti(card),
			"al_secondo": _budget.punti_al_secondo(card),
			"testo": card.short_text(),
		})

	righe.sort_custom(func(a, b): return a["al_secondo"] > b["al_secondo"])

	print("")
	print("%-16s %-24s %-10s %7s %7s %8s   %s" % [
		"id", "carta", "famiglia", "attesa", "punti", "punti/s", "cosa fa",
	])
	print("-".repeat(110))
	for riga in righe:
		print("%-16s %-24s %-10s %6.1fs %7.1f %8.2f   %s" % [
			riga["id"], riga["nome"], riga["famiglia"],
			riga["attesa"], riga["punti"], riga["al_secondo"], riga["testo"],
		])

	_riepilogo(righe)
	quit(0)
	return true


func _riepilogo(righe: Array) -> void:
	if righe.is_empty():
		print("\nnessuna carta: qualcosa non va nei dati.")
		return

	var per_famiglia: Dictionary = {}
	var totale := 0.0
	for riga in righe:
		totale += float(riga["al_secondo"])
		var f := String(riga["famiglia"])
		if not per_famiglia.has(f):
			per_famiglia[f] = []
		(per_famiglia[f] as Array).append(float(riga["al_secondo"]))

	print("-".repeat(110))
	print("%d carte · media %.2f punti/s · da %.2f (%s) a %.2f (%s)" % [
		righe.size(), totale / righe.size(),
		righe[-1]["al_secondo"], righe[-1]["nome"],
		righe[0]["al_secondo"], righe[0]["nome"],
	])

	var famiglie: Array = per_famiglia.keys()
	famiglie.sort()
	for f in famiglie:
		var valori: Array = per_famiglia[f]
		var somma := 0.0
		var minimo: float = valori[0]
		var massimo: float = valori[0]
		for v in valori:
			somma += float(v)
			minimo = minf(minimo, float(v))
			massimo = maxf(massimo, float(v))
		print("  %-12s %3d carte · media %.2f · banda %.2f–%.2f" % [
			f, valori.size(), somma / valori.size(), minimo, massimo,
		])
