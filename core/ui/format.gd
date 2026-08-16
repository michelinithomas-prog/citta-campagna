class_name Fmt
extends RefCounted
## Numeri leggibili a schermo. Serve soprattutto agli idle, dove i valori
## crescono di ordini di grandezza, ma va bene ovunque.
##
##   Fmt.number(1234)      -> "1.23K"
##   Fmt.number(45)        -> "45"
##   Fmt.time(3725)        -> "1h 2m"
##   Fmt.rate(12.5)        -> "12.5/s"

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


## Numero compatto. Sotto 1000 resta intero, sopra usa i suffissi.
static func number(value: float, decimals: int = 2) -> String:
	var sign_prefix := "-" if value < 0.0 else ""
	var amount := absf(value)

	if amount < 1000.0:
		return sign_prefix + (str(int(amount)) if is_equal_approx(amount, floorf(amount)) else "%.1f" % amount)

	var tier := int(floorf(log(amount) / log(1000.0)))
	tier = clampi(tier, 0, SUFFIXES.size() - 1)
	var scaled := amount / pow(1000.0, tier)

	# 999.99K invece di 1000.00K
	if scaled >= 999.995 and tier < SUFFIXES.size() - 1:
		tier += 1
		scaled = amount / pow(1000.0, tier)

	return "%s%s%s" % [sign_prefix, String.num(scaled, decimals), SUFFIXES[tier]]


## Produzione al secondo.
static func rate(value: float) -> String:
	return "%s/s" % number(value)


## Durata leggibile: "2g 3h", "5m 12s", "8s".
static func time(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	if total < 60:
		return "%ds" % total

	var minutes := total / 60
	if minutes < 60:
		return "%dm %ds" % [minutes, total % 60]

	var hours := minutes / 60
	if hours < 24:
		return "%dh %dm" % [hours, minutes % 60]

	return "%dg %dh" % [hours / 24, hours % 24]


## Percentuale: 0.35 -> "+35%"
static func percent(value: float, with_sign: bool = true) -> String:
	var text := "%d%%" % roundi(value * 100.0)
	return ("+" + text) if with_sign and value >= 0.0 else text
