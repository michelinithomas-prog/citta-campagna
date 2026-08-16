extends SceneTree
## Guarda la bottega mentre ci si compra dentro.
##
##   godot --headless --path templates/cittacampagna \
##         --script res://tools/repro_bottega.gd -- [seed]
##
## Conta i bottoni di ogni riga a ogni passaggio: se una riga cresce invece di
## essere ridisegnata, i vecchi nodi sono rimasti lì. Controlla anche che una
## reliquia comprata non torni in vendita e che le offerte cambino fra un round
## e l'altro.

var play: Node
var _frames := 0
var _passo := 0
var _errori := 0
var _prima_reliquia := ""
var _offerte_round1: Array[String] = []


func _initialize() -> void:
	var seed_value := 4242
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		seed_value = int(args[0])
	root.get_node("Rng").new_run(seed_value)

	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	# Questo strumento punta a una schermata precisa: i dialoghi li salta.
	# L'introduzione da sola sono centoventi battute, e non è quello che
	# sta misurando.
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 20 != 0:
		return false

	_passo += 1
	match _passo:
		1:
			play.run.earn(500)
			play._refresh_shop()
			_conta("appena entrato")
			for relic in play.market.relic_offers:
				_offerte_round1.append(String(relic.get("id", "")))
			print("   reliquie in vetrina: %s" % [_offerte_round1])
		2:
			print("\n-- compro una carta --")
			play._on_buy_card(0)
			_conta("dopo aver comprato una carta")
		3:
			print("\n-- compro un'altra carta --")
			play._on_buy_card(0)
			_conta("dopo la seconda carta")
		4:
			print("\n-- compro una reliquia --")
			if not play.market.relic_offers.is_empty():
				_prima_reliquia = String(play.market.relic_offers[0].get("id", ""))
				play._on_buy_relic(0)
			_conta("dopo la reliquia")
			print("   comprata: %s" % _prima_reliquia)
		5:
			# Sei accessi di fila comprando ogni volta: le righe non devono
			# gonfiarsi, le offerte devono cambiare, e niente di già comprato
			# deve ricomparire in vendita.
			var viste_uguali := 0
			var precedenti := _offerte_round1
			for giro in 6:
				play.run.finish_round(true)
				play.run.earn(300)
				play._enter_shop()
				# Può essersi messo di mezzo un incontro: la vetrina si rifà
				# quando si esce di lì, non prima. Si preme "Avanti" e si va.
				while play.phase == play.Phase.EVENT:
					var bottone := _primo_bottone(play._event_panel)
					if bottone == null:
						break
					bottone.pressed.emit()
				_conta("accesso %d" % (giro + 2))

				var ora: Array[String] = []
				for relic in play.market.relic_offers:
					ora.append(String(relic.get("id", "")))
				for id in ora:
					if play.run.has_relic(id):
						print("   ✗ %s è già mia e la rimettono in vendita" % id)
						_errori += 1
				if not ora.is_empty() and ora == precedenti:
					viste_uguali += 1
				precedenti = ora
				print("   vetrina: %s" % [ora])

				if not play.market.relic_offers.is_empty():
					play._on_buy_relic(0)

			if viste_uguali > 0:
				print("   ✗ %d accessi hanno mostrato la stessa identica vetrina" % viste_uguali)
				_errori += 1
		_:
			print("\n%s" % ("TUTTO A POSTO" if _errori == 0 else "%d PROBLEMI TROVATI" % _errori))
			quit(0 if _errori == 0 else 1)
			return true

	return false


func _primo_bottone(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var trovato := _primo_bottone(child)
		if trovato != null:
			return trovato
	return null


## Conta i nodi che la bottega ha davvero a schermo e li confronta con le
## offerte. Se qualcuno ridisegna una riga senza prima svuotarla, i numeri
## crescono a ogni acquisto.
##
## Si contano i nodi nell'albero, non le variabili membro della scena: quelle
## cambiano ogni volta che si rifà il layout, e una guardia che si appoggia a
## loro smette di controllare in silenzio (è già successo — dichiarava "tutto a
## posto" mentre un errore la interrompeva a metà).
func _conta(quando: String) -> void:
	var carte := _conta_carte(play._shop_panel)
	var bottoni := _conta_bottoni(play._shop_panel)

	# In vetrina: una CardView per carta offerta.
	var attese_carte: int = play.market.card_offers.size()
	# I bottoni: vedi mazzo, vedi reliquie, rimescola, butta, prosegui, più uno
	# per ogni reliquia e ogni innesto in vendita.
	var attesi_bottoni: int = 5 + play.market.relic_offers.size() + play.market.seal_offers.size()

	print("%s: carte %d/%d · bottoni %d/%d" % [quando, carte, attese_carte, bottoni, attesi_bottoni])

	if carte != attese_carte:
		print("   ✗ %d riquadri carta per %d offerte" % [carte, attese_carte])
		_errori += 1
	if bottoni != attesi_bottoni:
		print("   ✗ %d bottoni invece di %d: qualche riga non è stata svuotata" % [bottoni, attesi_bottoni])
		_errori += 1


## Si riconosce la carta dal percorso del suo script, non con `is CardView`:
## nominare la classe qui obbligherebbe Godot a compilare card_view.gd insieme a
## questo file, e quello usa gli autoload — che quando il MainLoop viene
## compilato non esistono ancora.
func _conta_carte(nodo: Node) -> int:
	var totale := 0
	for figlio in nodo.get_children():
		var script: Variant = figlio.get_script()
		if script != null and String(script.resource_path).ends_with("card_view.gd"):
			totale += 1
		totale += _conta_carte(figlio)
	return totale


func _conta_bottoni(nodo: Node) -> int:
	var totale := 0
	for figlio in nodo.get_children():
		if figlio is Button:
			totale += 1
		totale += _conta_bottoni(figlio)
	return totale
