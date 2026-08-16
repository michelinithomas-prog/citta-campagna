extends TestCase
## La predisposizione alla traduzione, sorvegliata.
##
## Il gioco è in italiano e resterà in italiano finché qualcuno non traduce.
## Quello che questi test difendono non è una traduzione: è la **possibilità**
## di farne una senza riscrivere il gioco. Sono quattro cose, e tutte e quattro
## si rompono in silenzio:
##
##   1. una stringa formattata prima di essere assegnata non viene mai tradotta;
##   2. una desinenza italiana cucita dentro un formato non è traducibile
##      affatto — la frase va rifatta, non tradotta;
##   3. una chiave che è anche un'etichetta, tradotta, fa sparire quello che
##      indicizzava;
##   4. un nome usato per costruire il percorso di un file, tradotto, toglie
##      il disegno alla carta.
##
## Nessuna delle quattro lascia un errore in console. Da qui i test.

const CATALOGO := "res://game/i18n/testi.csv"

## Le desinenze italiane che si trovavano cucite dentro i formati. Il `%s` che
## le porta non è una parola: è mezza parola, e in nessun'altra lingua esiste.
const DESINENZE := ["cart%s", "anell%s", "second%s", "punt%s", "innest%s"]


func _sorgenti() -> Array[String]:
	var out: Array[String] = []
	var da_visitare: Array[String] = ["res://game"]
	while not da_visitare.is_empty():
		var cartella: String = da_visitare.pop_back()
		var dir := DirAccess.open(cartella)
		if dir == null:
			continue
		dir.list_dir_begin()
		var nome := dir.get_next()
		while nome != "":
			var pieno := cartella.path_join(nome)
			if dir.current_is_dir():
				da_visitare.append(pieno)
			elif nome.ends_with(".gd"):
				out.append(pieno)
			nome = dir.get_next()
		dir.list_dir_end()
	return out


func _righe_di_codice(percorso: String) -> Array:
	var righe := FileAccess.get_file_as_string(percorso).split("\n")
	var out: Array = []
	for i in righe.size():
		var riga: String = righe[i]
		# I commenti spiegano il problema: non sono il problema.
		if riga.strip_edges().begins_with("#"):
			continue
		out.append({"n": i + 1, "testo": riga})
	return out


# --- le desinenze cucite -------------------------------------------------

func test_nessuna_desinenza_dentro_un_formato() -> void:
	# `"%d cart%s" % [n, "a" if n == 1 else "e"]` era la forma usata ovunque.
	# Chi la reintroduce fa un lavoro che nessun traduttore potrà finire.
	var colpevoli: Array[String] = []
	for percorso in _sorgenti():
		for riga: Dictionary in _righe_di_codice(percorso):
			for desinenza in DESINENZE:
				if String(riga["testo"]).contains(desinenza):
					colpevoli.append("%s:%d  %s" % [
						percorso.get_file(), riga["n"], String(riga["testo"]).strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"desinenze cucite dentro un formato — si usa Testo.plurale():\n  %s"
			% "\n  ".join(colpevoli))


func test_nessun_ternario_di_desinenza() -> void:
	# La firma dell'altro pezzo dello stesso trucco: la desinenza scelta con un
	# ternario e passata al formato.
	var colpevoli: Array[String] = []
	for percorso in _sorgenti():
		for riga: Dictionary in _righe_di_codice(percorso):
			var t := String(riga["testo"])
			for coppia in [['"a" if', 'else "e"'], ['"o" if', 'else "i"'], ['"" if', 'else "i"']]:
				if t.contains(coppia[0]) and t.contains(coppia[1]):
					colpevoli.append("%s:%d  %s" % [percorso.get_file(), riga["n"], t.strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"desinenze scelte con un ternario — si usa Testo.plurale():\n  %s"
			% "\n  ".join(colpevoli))


# --- Testo.plurale fa quello che dice ------------------------------------

func test_plurale_sceglie_la_forma_giusta() -> void:
	assert_eq(Testo.plurale(1, "una", "molte"), "una")
	assert_eq(Testo.plurale(0, "una", "molte"), "molte")
	assert_eq(Testo.plurale(2, "una", "molte"), "molte")
	# Il meno uno è singolare come l'uno: "-1 carta", non "-1 carte".
	assert_eq(Testo.plurale(-1, "una", "molte"), "una")


# --- il catalogo ---------------------------------------------------------

func test_il_catalogo_esiste_ed_e_leggibile() -> void:
	assert_true(FileAccess.file_exists(CATALOGO),
		"manca %s — si rigenera con tools/estrai_testi.py" % CATALOGO)


func test_ogni_carta_del_gioco_e_nel_catalogo() -> void:
	# Il catalogo lo costruisce uno script Python che ricompone i nomi delle
	# carte con la stessa regola di card.gd. Due regole scritte due volte
	# divergono: questo test è il punto in cui la divergenza diventa rossa
	# invece che silenziosa.
	var chiavi := _chiavi_del_catalogo()
	var mancanti: Array[String] = []
	for id in CardLibrary.all_ids():
		var carta := CardLibrary.build(id)
		if carta == null:
			continue
		if not chiavi.has(carta.display_name):
			mancanti.append("%s (%s)" % [carta.display_name, id])
	assert_eq(mancanti.size(), 0,
		"carte assenti dal catalogo — rilancia tools/estrai_testi.py:\n  %s"
			% "\n  ".join(mancanti))


func _chiavi_del_catalogo() -> Dictionary:
	var chiavi := {}
	var f := FileAccess.open(CATALOGO, FileAccess.READ)
	if f == null:
		return chiavi
	f.get_csv_line()  # l'intestazione
	while not f.eof_reached():
		var riga := f.get_csv_line()
		if riga.size() > 0 and riga[0] != "":
			chiavi[riga[0]] = true
	return chiavi


# --- le due trappole silenziose ------------------------------------------

func test_il_disegno_della_carta_non_dipende_da_una_traduzione() -> void:
	# `carte_art.gd` costruisce il percorso del disegno da `display_name` e da
	# `short`. Sono anche due cose che si vedono a schermo, quindi un giorno
	# qualcuno vorrà tradurle — e se le traduce **nel modello** invece che
	# alla vista, le carte perdono l'illustrazione senza un errore.
	#
	# La prova: con la lingua finta accesa — che altera OGNI stringa che passa
	# dalla traduzione — ogni carta deve continuare a trovare il suo disegno.
	var prima := TranslationServer.is_pseudolocalization_enabled()
	TranslationServer.set_pseudolocalization_enabled(true)

	var senza_disegno: Array[String] = []
	for id in CardLibrary.all_ids():
		var carta := CardLibrary.build(id)
		if carta != null and CarteArt.per_carta(carta) == null:
			senza_disegno.append(id)

	TranslationServer.set_pseudolocalization_enabled(prima)
	assert_eq(senza_disegno.size(), 0,
		"con la lingua finta queste carte perdono il disegno — il percorso del "
		+ "file passa da una stringa tradotta:\n  %s" % "\n  ".join(senza_disegno))


func test_la_chiave_del_record_non_e_un_etichetta_tradotta() -> void:
	# `tuning.json` dice quale voce del riepilogo è il record (`menu.best_stat`)
	# e `game_over.gd` la cerca dentro il dizionario di `RunState.stats()`.
	# Quella stringa fa due mestieri: indicizza e — attraverso `best_label` —
	# si mostra. Se qualcuno traduce la chiave, il record sparisce in silenzio.
	var chiave := String(Cfg.get_value("menu.best_stat", ""))
	assert_ne(chiave, "", "tuning.json: manca menu.best_stat")

	var run := RunState.new()
	var riepilogo := run.stats()
	assert_true(riepilogo.has(chiave),
		"menu.best_stat vale «%s» ma RunState.stats() ha %s: la chiave è stata "
		% [chiave, riepilogo.keys()]
		+ "tradotta o rinominata, e il record non si trova più")


# --- il testo non viene composto prima di essere tradotto ----------------

func test_nessun_formato_applicato_dentro_tr() -> void:
	# `tr("Vinte %d" % n)` cerca nel catalogo la frase col numero già dentro:
	# è lo stesso difetto di prima, solo scritto peggio perché sembra corretto.
	var colpevoli: Array[String] = []
	var forma := RegEx.create_from_string('tr\\(\\s*"[^"]*"\\s*%')
	for percorso in _sorgenti():
		for riga: Dictionary in _righe_di_codice(percorso):
			if forma.search(String(riga["testo"])) != null:
				colpevoli.append("%s:%d  %s" % [
					percorso.get_file(), riga["n"], String(riga["testo"]).strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"il %% va applicato DOPO tr(), non dentro — tr(\"a %%d\") %% x:\n  %s"
			% "\n  ".join(colpevoli))
