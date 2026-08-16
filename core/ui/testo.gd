class_name Testo
extends RefCounted
## Le forme di testo che sopravvivono a una traduzione.
##
## Godot traduce da solo il testo che finisce dentro `Label.text` o
## `Button.text`, usando la stringa italiana come chiave e restituendola
## invariata se quella chiave non c'è ancora. Quindi il grosso del gioco si
## traduce con un CSV e zero righe di codice, e si può tradurre a fette.
##
## Restano due forme che quel meccanismo non salva, ed è per quelle che esiste
## questo file:
##
##   1. il testo **formattato prima** di essere assegnato — `"%d di %d" % [...]`
##      arriva alla Label già composto, e la chiave cercata è la frase con i
##      numeri dentro, che nel catalogo non c'è. Si risolve con `tr()` prima
##      del `%`, e non serve niente da qui.
##   2. le **concordanze di genere e numero cucite dentro il formato**. Per
##      quelle c'è `plurale()`.


## Sceglie fra due frasi intere invece di cucire una desinenza dentro il formato.
##
##   Testo.plurale(n, "%d carta in mazzo", "%d carte in mazzo") % n
##
## Perché non `"%d cart%s" % [n, "a" if n == 1 else "e"]`, che è la forma che
## questo gioco usava dappertutto: quel `%s` porta una **desinenza italiana**,
## non una parola. In inglese non esiste, in tedesco nemmeno, e nessun catalogo
## può contenerla — la frase andrebbe rifatta da capo invece che tradotta. Due
## frasi intere sono due chiavi che un traduttore sa leggere e che un CSV sa
## contenere.
##
## **Limite dichiarato, perché si sappia prima e non dopo:** due forme. Bastano
## per inglese, spagnolo, francese, tedesco, portoghese. Le lingue slave ne
## vogliono tre e chiedono i plurali veri del formato `.po`. Quel giorno cambia
## questa funzione, non i suoi punti d'uso — ed è tutto il motivo per cui la
## scelta sta qui dentro invece che sparsa in venti file.
static func plurale(quanti: int, singolare: String, molti: String) -> String:
	return traduci(singolare if absi(quanti) == 1 else molti)


## Traduce una stringa che arriva dai dati e non da una costante nel codice —
## il nome di una carta, di una reliquia, di un avversario.
##
## `tr()` fa la stessa cosa ma è un metodo di Object: da una funzione statica
## non si raggiunge. Da qui il passaggio esplicito dal TranslationServer.
static func traduci(chiave: String) -> String:
	return TranslationServer.translate(chiave)


## Il pezzo di frase che vale solo in una lingua, tenuto fuori dalle chiavi.
##
## Serve ai casi in cui il gioco compone un elenco: «le sue carte di Coppe» e
## «le sue carte» sono due frasi intere, non una frase con un buco.
static func elenco(voci: Array[String], congiunzione: String = "e") -> String:
	if voci.is_empty():
		return ""
	if voci.size() == 1:
		return voci[0]
	var testa: Array[String] = voci.slice(0, voci.size() - 1)
	return "%s %s %s" % [", ".join(testa), traduci(congiunzione), voci[-1]]
