extends SceneTree
## La schermata di battaglia sta ferma, o balla?
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/misura_stabilita.gd -- [round] [seed]
##
## Esce con 1 se qualcosa cambia larghezza mentre la battaglia va avanti.
##
## Perché serve uno strumento e non un test: la battaglia è una scena, e i test
## di `tests/` non la costruiscono. Ed è un difetto che nessun test di logica
## potrebbe vedere — le regole funzionano benissimo mentre lo schermo balla.
##
## Il difetto che ha fatto nascere questo strumento: la riga di resoconto sotto
## le carte non aveva nessun vincolo di larghezza, quindi la sua larghezza
## minima era quella del testo intero — da 132 px («Tu — Due di Coppe: 2 cura»)
## a 1169 px («Il Vecchio Contadino — Re di Bastoni: 4 rallenta · 2 indebolisce
## · 5 danni · …»). Cambiando a ogni attivazione, quaranta volte a battaglia,
## allargava e stringeva la colonna centrale e con lei tutta la schermata.

## Sotto questa soglia è assestamento del primo frame, non ballo.
const TOLLERANZA := 1.0

var _play: Node
var _frame := 0
var _round := 3
var _seed := 4242
var _storia := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_round = int(args[0])
	if args.size() >= 2:
		_seed = int(args[1])

	root.get_node("Rng").new_run(_seed)
	var scena: PackedScene = load("res://game/play.tscn")
	_play = scena.instantiate()
	_play.senza_dialoghi = true
	root.add_child(_play)


func _process(_delta: float) -> bool:
	_frame += 1

	# Si porta la run al round chiesto, poi si entra in battaglia.
	# Phase: EVENT=0 · SHOP=1 · PREVIEW=2 · BATTLE=3
	if _frame == 8:
		while _play.run.round_number < _round:
			_play.run.finish_round(true)
		_play._enter_shop()
	if _frame == 16 and _play.phase == 1:
		_play._prosegui()
	if _frame == 24 and _play.phase == 2:
		_play._start_battle()

	if _play.duel != null and not _play.duel.is_over:
		_play.duel.advance(1.0 / 30.0)

	# Si comincia a guardare dopo che il layout si è assestato: i contenitori
	# di Godot calcolano le misure in differita, e i primi frame sono sempre
	# in movimento senza che sia colpa di nessuno.
	if _frame > 40 and _play.phase == 3:
		var pannello: Node = _play.get("_battle_panel")
		if pannello != null and pannello.visible:
			_guarda(pannello, "", 0)

	if _frame > 700:
		return _referto()
	return false


func _guarda(nodo: Node, percorso: String, profondita: int) -> void:
	if profondita > 4 or not (nodo is Control):
		return
	var c := nodo as Control
	var nome := "%s/%s" % [percorso, nodo.name]
	var testo := ""
	if c is Label:
		testo = (c as Label).text
	elif c is Button:
		testo = (c as Button).text

	if not _storia.has(nome):
		_storia[nome] = {"min": c.size.x, "max": c.size.x, "stretto": testo, "largo": testo}
	else:
		var s: Dictionary = _storia[nome]
		if c.size.x < s["min"]:
			s["min"] = c.size.x
			s["stretto"] = testo
		if c.size.x > s["max"]:
			s["max"] = c.size.x
			s["largo"] = testo

	for figlio in nodo.get_children():
		_guarda(figlio, nome, profondita + 1)


func _referto() -> bool:
	var mobili: Array = []
	for nome: String in _storia:
		var s: Dictionary = _storia[nome]
		if s["max"] - s["min"] > TOLLERANZA:
			mobili.append({"nome": nome, "esc": s["max"] - s["min"], "s": s})
	mobili.sort_custom(func(a, b): return a["esc"] > b["esc"])

	print("round %d, seed %d — %d nodi osservati" % [_round, _seed, _storia.size()])
	if mobili.is_empty():
		print("LA SCHERMATA STA FERMA")
		quit(0)
		return true

	print("\nQUESTI NODI CAMBIANO LARGHEZZA MENTRE LA BATTAGLIA VA AVANTI:")
	for m in mobili.slice(0, 10):
		var s: Dictionary = m["s"]
		var nome: String = m["nome"]
		print("  %6.0f px di escursione  (da %.0f a %.0f)  %s" % [
			m["esc"], s["min"], s["max"], nome.substr(maxi(0, nome.length() - 46))])
		if String(s["largo"]) != "":
			print("        col testo: «%s»" % String(s["largo"]).substr(0, 66))
	quit(1)
	return true
