class_name CardBudget
extends RefCounted
## Il metro con cui si confrontano fra loro carte che fanno cose diverse.
##
## Non è una regola di gioco: nessuno lo chiama in battaglia. Serve a
## `tests/budget_test.gd` e a `tools/diagnosi_carte.gd`, che devono usare lo
## stesso modello o smettono di parlarsi — e con centocinquanta carte da tarare
## a mano, un metro che dice due cose diverse è peggio di nessun metro.
##
## Un punto vale un danno. Il resto si converte:
##
##   scudo  0.8   vale meno di un danno: può andare sprecato
##   cura   0.9   vale meno di un danno: è limitata dagli hp massimi
##   oro    2.0   una moneta oggi è mezza carta domani
##
## I due danni nel tempo non valgono il loro numero, valgono il loro **totale**:
##
##   sanguinamento N   N + (N-1) + ... + 1  =  N(N+1)/2, poi si spegne
##   veleno N          N per ogni secondo che resta, cioè in media metà battaglia
##
## È il veleno il motivo per cui questo file esiste: a occhio sembra il fratello
## piccolo del sanguinamento, e invece a parità di numero vale cinque volte tanto.

## Quanto dura una battaglia, per il conto del veleno. Se le battaglie si
## allungano il veleno diventa più forte senza che nessuno tocchi un numero:
## tenerlo scritto qui è il modo di accorgersene.
const SECONDI_ATTESI := 18.0

## Ogni quanti secondi morde il veleno. Deve restare uguale a
## `battle.poison_every` in tuning.json: qui non si può leggere Cfg (il metro
## gira anche fuori dal gioco), quindi lo controlla `data_test`.
const VELENO_OGNI := 3.0

const PESI := {
	"damage": 1.0,
	"shield": 0.8,
	"heal": 0.9,
	"gold": 2.0,
}

## E i verbi che non hanno una statistica: quanto vale un'unità di ciascuno.
## Senza questa tabella metà del catalogo risulterebbe vuota — un Nove che
## scarta due carte avversarie peserebbe zero — e finirebbe prezzato come una
## carta che non fa niente.
##
## Le unità sono quelle di `Card._quantita`: secondi per chi manipola il tempo,
## carte per chi manipola il mazzo, slot × forza per i buff.
const PESI_UTILITY := {
	"burn": 5.0,          ## toglie una carta dalla plancia *e* costringe a pescare
	"steal": 8.0,         ## come burn, ma la carta la tieni tu
	"mill": 3.0,          ## una carta di mazzo altrui: colpo differito
	"recover": 3.0,       ## una carta di mazzo tua, che è la stessa cosa al contrario
	"spawn_card": 3.0,
	"recycle": 3.0,       ## per ogni rientro concesso
	"slow": 2.0,          ## per secondo rubato all'avversario
	"haste": 2.0,         ## per secondo regalato a sé stessi
	"paralyze": 2.0,      ## per secondo di gelo (già moltiplicato per gli slot)
	"value_debuff": 3.0,  ## per punto tolto alla plancia avversaria
	"match_buff": 6.0,    ## per punto, ma vale per tutte le carte che restano
	"slot_buff": 3.0,     ## per unità di forza × slot
	"cleanse": 3.0,

	## La catena di One. Un anello moltiplica colpi, cure e scudi di **tutte** le
	## attivazioni che restano: con una dozzina di carte ancora da giocare e un
	## passo del 10%, vale quanto una carta intera. È il numero più delicato di
	## questa tabella — se le battaglie si allungano, cresce da solo.
	"combo": 8.0,
	## E spegnerla costa altrettanto. Serve solo alla carta Blocco, che nel mazzo
	## ci va per scelta di chi gioca il Pesca Quattro.
	"combo_reset": -8.0,
}


## I punti che una carta eroga in un'attivazione, aura compresa.
static func punti(card) -> float:
	var line: Dictionary = card.stat_line()
	var out := _pesa(line)

	# Un'aura rende per tutto il tempo in cui la carta resta in plancia, cioè
	# per la sua attesa: è la ragione per cui un seme d'erba con un cooldown
	# lunghissimo non è una carta debole.
	var tick: Dictionary = line.get("tick", {})
	if not tick.is_empty():
		out += _pesa(tick) * float(card.interval())
	return out


static func _pesa(line: Dictionary) -> float:
	var out := 0.0
	for key in PESI:
		out += float(line.get(key, 0.0)) * float(PESI[key])

	var sangue := float(line.get("bleed", 0.0))
	out += sangue * (sangue + 1.0) * 0.5
	out += float(line.get("poison", 0.0)) * (SECONDI_ATTESI * 0.5 / VELENO_OGNI)

	for verbo in line.get("utility", {}):
		out += float(line["utility"][verbo]) * float(PESI_UTILITY.get(verbo, 0.0))
	return out


## Il numero che conta davvero: quanto rende la carta al secondo. È l'unica
## grandezza confrontabile fra una carta veloce e piccola e una lenta e grossa.
static func punti_al_secondo(card) -> float:
	var attesa: float = card.interval()
	return punti(card) / attesa if attesa > 0.0 else 0.0
