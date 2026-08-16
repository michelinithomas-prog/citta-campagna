extends SceneTree
## Registra una battaglia **intera**, dalla prima carta che parte al verdetto.
##
##   godot --path templates/cittacampagna --fixed-fps 60 \
##         --script res://tools/registra_battaglia.gd -- <cartella> [round] [seed] [velocità] [passo]
##
##   godot --path templates/cittacampagna --fixed-fps 60 \
##         --script res://tools/registra_battaglia.gd -- /tmp/battaglia 9 4242 1
##
## Poi, per farne un video:
##
##   ffmpeg -framerate 60 -i /tmp/battaglia/f%04d.png \
##          -c:v libx264 -pix_fmt yuv420p -crf 20 battaglia.mp4
##
## `foto_clip.gd` registra nove secondi di una scena scelta, per una vetrina.
## Questo registra **tutta** la partita a tavolino, che dura una trentina di
## secondi simulati e non si sa in anticipo quanti: si ferma quando il duello
## finisce, più un paio di secondi per far leggere il verdetto.
##
## ## Il tempo se lo governa lo strumento, non l'orologio
##
## Salvare un PNG da 1152×648 costa due decimi di secondo, e Godot non aspetta:
## continua a simulare e salta i disegni. Registrando quello che passa esce una
## battaglia venti volte più veloce del vero.
##
## - **`--fixed-fps 60` è obbligatorio**: sgancia il `delta` dall'orologio, ogni
##   iterazione vale 1/60 di secondo di gioco qualunque cosa succeda;
## - il disegno **si chiede** con `RenderingServer.force_draw()`, una iterazione
##   ogni `PASSO`.
##
## **Va lanciato in primo piano**: in background la finestra non disegna e la
## registrazione resta vuota senza dirlo.

## Un disegno ogni `_passo` iterazioni. Con 1 escono 60 fotogrammi al secondo —
## quanti ne disegna il gioco — e il video è fluido come il gioco; con 3 ne
## escono 20, che pesano un terzo ma si vedono a scatti. Il valore giusto
## dipende da cosa serve: 1 per far vedere il gioco, 3 per una vetrina leggera.
var _passo := 1

## Quanto si continua a registrare dopo che il duello è finito, in sessantesimi.
## Serve al verdetto e al riepilogo, che arrivano dopo un'attesa deliberata.
const CODA := 200

const SALVATAGGIO := "user://save.json"
const MESSO_DA_PARTE := "user://save.json.registrazione"

var play: Node
var _dir := "/tmp/battaglia"
var _round := 9
var _seed := 4242
var _velocita := 1.0

var _frames := 0
var _scatti := 0
var _registra := false
var _spostato := false
var _finito_a := -1
## Quando suona cosa: serve a rimettere l'audio sul video.
var _eventi: Array = []
var _inizio_scatti := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_dir = args[0]
	if args.size() >= 2:
		_round = int(args[1])
	if args.size() >= 3:
		_seed = int(args[2])
	if args.size() >= 4:
		_velocita = maxf(float(args[3]), 0.1)
	if args.size() >= 5:
		_passo = clampi(int(args[4]), 1, 6)

	DirAccess.make_dir_recursive_absolute(_dir)
	if FileAccess.file_exists(SALVATAGGIO):
		if DirAccess.copy_absolute(SALVATAGGIO, MESSO_DA_PARTE) == OK:
			_spostato = true

	root.get_node("Rng").new_run(_seed)
	var packed: PackedScene = load("res://game/play.tscn")
	play = packed.instantiate()
	play.senza_dialoghi = true
	root.add_child(play)
	current_scene = play


func _finalize() -> void:
	if _spostato:
		DirAccess.copy_absolute(MESSO_DA_PARTE, SALVATAGGIO)
		DirAccess.remove_absolute(MESSO_DA_PARTE)


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 5:
		# Si porta la run al round chiesto: gli ultimi avversari hanno mazzi più
		# ricchi, ed è lì che il gioco mostra quello che sa fare.
		while play.run.round_number < _round:
			play.run.finish_round(true)
		play._start_battle()
		# La velocità si impone al duello appena creato e **non** scrivendo
		# `options.battle_speed`: quella è un'impostazione dell'utente, sta nel
		# salvataggio, e uno strumento non gliela cambia per sempre.
		play.duel.speed_up(_velocita)
		# Si comincia alla prima carta che parte: prima c'è solo un tavolo fermo.
		# E si annota QUANDO parte ciascuna, per poter rimettere i suoni ai
		# tempi giusti sul video: il gioco suona `hit` per le mie carte e
		# `hurt` per le sue, e senza questi tempi la registrazione resterebbe
		# un film muto.
		play.duel.card_activated.connect(func(lato, _i, _c) -> void:
			if not _registra:
				_registra = true
				_inizio_scatti = _scatti
			_eventi.append({
				"secondo": float(_scatti - _inizio_scatti) / (60.0 / _passo),
				"suono": "hit" if lato.is_player else "hurt",
			})
		)
		play.duel.card_burned.connect(func(_l, _i, _c) -> void:
			_eventi.append({
				"secondo": float(_scatti - _inizio_scatti) / (60.0 / _passo),
				"suono": "explosion",
			})
		)

	if _registra and _frames % _passo == 0:
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("%s/f%04d.png" % [_dir, _scatti])
		_scatti += 1

	if _finito_a < 0 and play.duel != null and play.duel.is_over:
		_finito_a = _frames
		print("[DUELLO] finito dopo %.1fs simulati — %d attivazioni, esito %s (%s)" % [
			play.duel.elapsed, play.duel.activations,
			"vinta" if play.duel.won else "persa", play.duel.reason])

	if _finito_a > 0 and _frames > _finito_a + CODA:
		# L'esito finale ha il suo suono, come in gioco.
		_eventi.append({
			"secondo": float(_finito_a - 5) / 60.0 - float(_inizio_scatti) / (60.0 / _passo),
			"suono": "confirm" if play.duel.won else "cancel",
		})
		var f := FileAccess.open("%s/suoni.json" % _dir, FileAccess.WRITE)
		f.store_string(JSON.stringify({
			"fps": 60.0 / _passo,
			"fotogrammi": _scatti,
			"eventi": _eventi,
		}, "  "))
		print("[REGISTRATO] %d fotogrammi in %s" % [_scatti, _dir])
		print("             a %.0f fps sono %.1f secondi di video" % [60.0 / _passo, _scatti / (60.0 / _passo)])
		print("             %d eventi sonori annotati" % _eventi.size())
		quit(0)
		return true

	if _frames > 20000:
		print("[NIENTE] la battaglia non è mai partita (%d fotogrammi)" % _scatti)
		quit(1)
		return true
	return false
