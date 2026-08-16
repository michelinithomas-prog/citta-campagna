extends Node
## Suono e musica.
##
##   Audio.sfx("click")
##   Audio.sfx("hit", 1.2)          # con variazione di intonazione
##   Audio.music("res://game/audio/battle.ogg")
##   Audio.set_volume("sfx", 0.5)   # persistito nel salvataggio
##
## Da dove arriva un suono, in ordine:
##   1. res://game/audio/<nome>.ogg  o  .wav   ← i tuoi file, se ci sono
##   2. un suono sintetico con lo stesso nome  ← vedi SfxSynth.preset_names()
##
## Così il template suona da subito e mettere i file veri il giorno della jam
## non richiede di toccare una riga di codice.
##
## I bus audio sono creati a runtime: nessun default_bus_layout.tres da gestire.

const AUDIO_DIR := "res://game/audio/"
const VOICES := 12

## I tre bus regolabili, dal nome usato nel codice e nel salvataggio a quello
## vero dentro AudioServer.
const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX"}

var _music_player: AudioStreamPlayer
var _music_fading: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _inizio_voce: Array[int] = []
var _next_voice := 0
var _cache: Dictionary = {}
var _current_music_path := ""

## Il tween di dissolvenza in corso su ciascuno dei due player della musica.
## Serve a poterlo uccidere prima di riusare quel player: due cambi di traccia
## a distanza minore della dissolvenza si contendevano lo stesso nodo, e il
## secondo brano partiva per essere subito trascinato a -60 dB e fermato dal
## tween del primo. Sintomo: la musica sparisce, senza un errore in console.
var _tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()

	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_voices.append(player)
		_inizio_voce.append(0)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	_music_fading = AudioStreamPlayer.new()
	_music_fading.bus = "Music"
	add_child(_music_fading)

	for bus in BUSES:
		set_volume(bus, float(Save.get_value("audio." + bus, 1.0)), false)

	# F5 rilegge tuning, contenuti e tema: da qui rilegge anche l'audio.
	Events.content_reloaded.connect(reload)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


# --- effetti ------------------------------------------------------------

## `pitch` 1.0 = normale. Passa un valore casuale (es. randf_range(0.9, 1.1))
## per evitare l'effetto mitragliatrice quando lo stesso suono si ripete.
func sfx(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _resolve_sfx(name)
	if stream == null:
		return

	var player := _voce_libera()
	player.stream = stream
	player.pitch_scale = maxf(pitch, 0.01)
	player.volume_db = volume_db
	player.play()


## Una voce che non sta suonando; se sono tutte occupate, la più vecchia.
##
## La rotazione cieca di prima riusava la voce successiva senza guardare se
## stesse ancora suonando: con una raffica di venti suoni in un frame — il caso
## normale di towerdefense, con un colpo per proiettile — i primi otto venivano
## troncati a metà. Rubare la più vecchia toglie sempre il suono che ha già
## detto quasi tutto quello che aveva da dire.
func _voce_libera() -> AudioStreamPlayer:
	for i in VOICES:
		var indice := (_next_voice + i) % VOICES
		if not _voices[indice].playing:
			_next_voice = (indice + 1) % VOICES
			_inizio_voce[indice] = Time.get_ticks_msec()
			return _voices[indice]

	var piu_vecchia := 0
	for i in VOICES:
		if _inizio_voce[i] < _inizio_voce[piu_vecchia]:
			piu_vecchia = i
	_next_voice = (piu_vecchia + 1) % VOICES
	_inizio_voce[piu_vecchia] = Time.get_ticks_msec()
	return _voices[piu_vecchia]


func _resolve_sfx(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]

	var path := _percorso_audio(name)
	var stream: AudioStream = load(path) if not path.is_empty() else null

	if stream == null:
		stream = SfxSynth.preset(name)
	if stream == null:
		push_warning('Audio: nessun suono chiamato "%s" (né file né preset)' % name)

	_cache[name] = stream
	return stream


## Il file in `game/audio/` che porta questo nome, o "" se non ce n'è nessuno.
## Le estensioni si provano in quest'ordine e la prima che esiste vince.
func _percorso_audio(name: String) -> String:
	for extension: String in [".ogg", ".wav", ".mp3"]:
		var path := AUDIO_DIR + name + extension
		if ResourceLoader.exists(path):
			return path
	return ""


## Svuota la cache dei suoni risolti.
##
## Senza, la promessa "metti il file in game/audio/ e premi F5" è falsa: un
## nome già risolto una volta resta sintetico fino al riavvio, e chi prova
## crede che il file non sia stato preso.
func reload() -> void:
	_cache.clear()


# --- musica -------------------------------------------------------------

## Passa "" per fermare la musica. Se la traccia è già in riproduzione non
## riparte da capo.
##
## Accetta due forme, e la seconda è quella da usare:
##   Audio.music("res://game/audio/battle.ogg")   un path esplicito
##   Audio.music("musica_battaglia")              un nome, come per gli effetti
## Col nome vale la stessa promessa di `sfx()`: si cerca in `game/audio/` con le
## stesse estensioni e nello stesso ordine. Così mettere il file e toglierlo
## resta l'unico gesto necessario, per la musica come per i suoni.
##
## Un path che non esiste **non** diventa la traccia corrente: altrimenti il
## controllo qui sopra lo scarterebbe per sempre e l'unico modo di rimettere
## la musica sarebbe passare da un terzo path.
func music(nome_o_path: String, fade: float = 0.8) -> void:
	var path := nome_o_path
	if not path.is_empty() and not path.contains("://"):
		path = _percorso_audio(nome_o_path)

	if path == _current_music_path:
		return

	if _music_player.playing:
		_crossfade_out(fade)

	# Da qui `_music_player` è il player entrante. Se si porta dietro un tween
	# di una dissolvenza precedente va ucciso, o quello lo riporta a -60 dB.
	_kill_tween(_music_player)

	if path.is_empty() or not ResourceLoader.exists(path):
		if not path.is_empty():
			push_warning("Audio: traccia non trovata — %s" % path)
		_current_music_path = ""
		return

	var stream := load(path)
	if stream is AudioStream:
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = true
		elif stream is AudioStreamWAV:
			# Il .wav non ha `loop`: ha `loop_mode`, ed è la ragione per cui una
			# musica in .wav suonava una volta sola e poi silenzio.
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
		_current_music_path = path
		_music_player.stream = stream
		_music_player.volume_db = -60.0
		_music_player.play()
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", 0.0, fade)
		_tweens[_music_player] = tween
	else:
		_current_music_path = ""


func _crossfade_out(fade: float) -> void:
	var outgoing := _music_fading
	_music_fading = _music_player
	_music_player = outgoing

	_kill_tween(_music_fading)
	var tween := create_tween()
	tween.tween_property(_music_fading, "volume_db", -60.0, fade)
	tween.tween_callback(_music_fading.stop)
	_tweens[_music_fading] = tween


func _kill_tween(player: AudioStreamPlayer) -> void:
	var tween: Tween = _tweens.get(player)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(player)


func stop_music(fade: float = 0.5) -> void:
	music("", fade)


# --- volumi -------------------------------------------------------------

## `bus`: "master" | "music" | "sfx". `value` da 0.0 a 1.0.
##
## Il nome del bus passa da BUSES e non da `capitalize()`: quella trasformava
## "SFX" in "Sfx", che non è un bus, e si usciva muti — mentre `get_volume`
## rispondeva lo stesso un numero plausibile, letto dal salvataggio. Un nome
## sbagliato adesso lo dice.
func set_volume(bus: String, value: float, persist: bool = true) -> void:
	if not BUSES.has(bus):
		push_warning('Audio: nessun bus chiamato "%s" (sono %s)' % [bus, ", ".join(BUSES.keys())])
		return
	var index := AudioServer.get_bus_index(BUSES[bus])
	if index == -1:
		return
	var clamped := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.001)))
	if persist:
		Save.set_value("audio." + bus, clamped)


func get_volume(bus: String) -> float:
	return float(Save.get_value("audio." + bus, 1.0))
