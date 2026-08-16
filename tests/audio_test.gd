extends TestCase
## La tavolozza sonora, sorvegliata come si sorvegliano i disegni delle carte.
##
## Il gioco suona con due materiali soli — l'ancia della fisarmonica e il legno
## del bancone — e la regola che lo tiene in piedi è che **nessun suono torni
## sintetico di nascosto**. Se un file sparisce o cambia nome, `Audio` ripiega
## sul preset di `SfxSynth` senza dire niente: nessun errore, nessun warning
## in console, solo un bip da console a 8 bit in mezzo a un valzer. È
## esattamente la stessa trappola dei disegni delle carte, e si chiude allo
## stesso modo.
##
## I file li genera `tools/genera_audio.py`. Rigenerarli due volte dà file
## identici byte per byte: se questo test diventa rosso, o manca un file o
## qualcuno ha rinominato un preset nel core.

const CARTELLA := "res://game/audio/"

## Le tracce chieste per nome dal gioco. Vivono come costanti in due file:
## `play.gd` (bottega e battaglia) e `game/ui/main_menu.gd` (il menu).
const MUSICHE := ["musica_menu", "musica_bottega", "musica_battaglia"]


func _percorso(nome: String) -> String:
	for estensione in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(CARTELLA + nome + estensione):
			return CARTELLA + nome + estensione
	return ""


# --- gli effetti ---------------------------------------------------------

func test_ogni_preset_del_core_ha_il_suo_file() -> void:
	# `SfxSynth.preset_names()` è l'elenco dei suoni che il core sa produrre da
	# solo. Ognuno deve avere un file che lo sostituisce, o quel suono resta
	# fuori dalla tavolozza.
	for nome: String in SfxSynth.preset_names():
		assert_ne(_percorso(nome), "",
			"nessun file per «%s»: il gioco ripiegherebbe sul sintetico" % nome)


func test_nessun_suono_arriva_dal_sintetizzatore() -> void:
	# La prova non è che lo stream esista — esiste in entrambi i casi — ma che
	# abbia un `resource_path`: quello sintetizzato nasce in memoria e ce l'ha
	# vuoto.
	Audio.reload()
	for nome: String in SfxSynth.preset_names():
		var stream: AudioStream = Audio._resolve_sfx(nome)
		assert_not_null(stream, "«%s» non si risolve affatto" % nome)
		assert_ne(stream.resource_path, "",
			"«%s» viene ancora dal sintetizzatore" % nome)


func test_gli_effetti_sono_corti() -> void:
	# Un effetto che dura più di due secondi si accavalla con se stesso: a 4×
	# il gioco spara fino a cinque suoni al secondo. Le uniche eccezioni sono
	# le due cadenze di fine partita, che suonano a tavolo fermo.
	var lunghi := ["win", "lose"]
	for nome: String in SfxSynth.preset_names():
		if nome in lunghi:
			continue
		var stream: AudioStream = load(_percorso(nome))
		assert_lt(stream.get_length(), 2.0,
			"«%s» dura %.2f s: troppo per un effetto" % [nome, stream.get_length()])


# --- la musica -----------------------------------------------------------

func test_ogni_traccia_chiesta_dal_gioco_esiste() -> void:
	for nome: String in MUSICHE:
		assert_ne(_percorso(nome), "", "manca la traccia «%s»" % nome)


func test_la_musica_e_in_ogg() -> void:
	# È l'unico formato che Godot cicla senza lasciare un buco: il .wav vuole
	# `loop_mode` invece di `loop`, e l'.mp3 in loop lascia un silenzio.
	for nome: String in MUSICHE:
		var stream: AudioStream = load(_percorso(nome))
		assert_true(stream is AudioStreamOggVorbis,
			"«%s» non è un ogg ma un %s" % [nome, stream.get_class()])


func test_le_tracce_durano_abbastanza_da_non_annoiare() -> void:
	for nome: String in MUSICHE:
		var stream: AudioStream = load(_percorso(nome))
		assert_gt(stream.get_length(), 8.0,
			"«%s» dura %.1f s: un anello così corto si sente ripetere"
				% [nome, stream.get_length()])


# --- il motore -----------------------------------------------------------

func test_un_nome_di_traccia_vale_quanto_un_percorso() -> void:
	# `Audio.music("musica_menu")` deve risolvere come `Audio.sfx("click")`:
	# è ciò che rende vera la promessa «metti il file e non toccare il codice»
	# anche per la musica.
	Audio.music("musica_menu", 0.01)
	assert_true(Audio._current_music_path.ends_with("musica_menu.ogg"),
		"risolta in «%s»" % Audio._current_music_path)
	Audio.music("", 0.01)


func test_una_traccia_inesistente_non_blocca_le_successive() -> void:
	Audio.music("questa_non_esiste", 0.01)
	assert_eq(Audio._current_music_path, "",
		"una traccia mancante non deve diventare quella corrente")
	Audio.music("musica_menu", 0.01)
	assert_true(Audio._current_music_path.ends_with("musica_menu.ogg"))
	Audio.music("", 0.01)
