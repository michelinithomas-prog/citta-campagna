extends TestCase
## Quello che si legge accanto alla barra della vita durante la battaglia.
##
## Non è decorazione: il veleno toglie vita ogni tre secondi e non si vede
## arrivare, la catena moltiplica tutto quello che succede dopo, e le carte
## ferme spiegano perché la plancia sembra bloccata. Se un numero non compare,
## il giocatore subisce qualcosa che non ha modo di capire.

var side: Side
var panel: SidePanel


func before_each() -> void:
	side = Side.new("prova", _carte(20), RngStream.new(7), {"hp": 100, "is_player": true})
	side.begin()
	panel = SidePanel.new(side)


func after_each() -> void:
	if panel != null:
		panel.free()
		panel = null
	side = null


func _carte(count: int) -> Array[Card]:
	var out: Array[Card] = []
	for i in count:
		out.append(CardLibrary.build("picche_c5"))
	return out


## Il testo del gettone di quello stato, o "" se è spento.
func _gettone(sigla: String) -> String:
	panel.refresh()
	for i in SidePanel.STATI.size():
		if String(SidePanel.STATI[i]["sigla"]) != sigla:
			continue
		return panel._gettoni[i].text if panel._gettoni[i].visible else ""
	fail("nessun gettone si chiama %s" % sigla)
	return ""


func test_a_riposo_non_si_legge_nessuno_stato() -> void:
	# Una riga piena di zeri costringe a leggerla tutta per scoprire che non c'è
	# niente da leggere.
	for stato in SidePanel.STATI:
		assert_eq(_gettone(String(stato["sigla"])), "",
			"%s non deve comparire quando non c'è" % stato["sigla"])


func test_il_veleno_si_vede() -> void:
	side.apply_poison(3)
	assert_eq(_gettone("VEL"), "VEL 3")


func test_il_sanguinamento_si_vede_e_cala_sotto_gli_occhi() -> void:
	side.apply_bleed(4)
	assert_eq(_gettone("SAN"), "SAN 4")

	side.tick_bleed()
	assert_eq(_gettone("SAN"), "SAN 3", "il numero deve scendere insieme allo stato")


func test_lo_scudo_si_vede_e_sparisce_quando_finisce() -> void:
	side.add_shield(12)
	panel.refresh()
	assert_eq(panel._shield.text, "◈ 12")

	side.take_damage(12)
	panel.refresh()
	assert_eq(panel._shield.text, "", "a scudo finito il numero se ne va")


func test_le_carte_ferme_si_contano() -> void:
	side.paralyze(2.0, 0)
	side.paralyze(2.0, 1)
	assert_eq(_gettone("GELO"), "GELO 2", "quante sono ferme, non per quanto")


func test_la_catena_si_vede_crescere() -> void:
	side.add_combo(3)
	assert_eq(_gettone("CATENA"), "CATENA 3")
	side.reset_combo()
	assert_eq(_gettone("CATENA"), "", "spenta la catena, sparisce anche il numero")


func test_il_bonus_di_fine_partita_si_vede_sommato() -> void:
	# Due Re nella stessa battaglia sono un numero solo da leggere.
	side.add_match_mod("value", StatBlock.FLAT, 2.0)
	side.add_match_mod("value", StatBlock.FLAT, 1.0)
	assert_eq(_gettone("BONUS"), "BONUS 3")


func test_ogni_stato_ha_un_colore_suo() -> void:
	# Due stati dello stesso colore si confondono proprio nel momento in cui
	# bisogna leggerli in fretta. Il veleno in particolare **non** è verde: in
	# questo gioco il verde vuol dire che ti sta facendo bene.
	var visti := {}
	for stato in SidePanel.STATI:
		var colore: Color = stato["colore"]
		assert_false(visti.has(colore), "%s ha lo stesso colore di %s" % [stato["sigla"], visti.get(colore, "?")])
		visti[colore] = stato["sigla"]
	assert_ne(Hud.VELENO, Hud.CURA, "il veleno non può avere il colore della cura")


func test_la_riga_si_monta_davvero() -> void:
	# `barra()` è l'unico punto in cui i gettoni entrano nell'albero, e non lo
	# chiama nessun altro test: senza questo un errore di tipi lì dentro si
	# scoprirebbe solo aprendo una battaglia — cioè mai, in una suite headless.
	side.apply_poison(2)
	var riga := panel.barra()
	assert_not_null(riga)

	var trovati := 0
	for gettone in panel._gettoni:
		if gettone.get_parent() != null:
			trovati += 1
	assert_eq(trovati, SidePanel.STATI.size(), "tutti i gettoni devono stare nella riga")
	riga.free()
