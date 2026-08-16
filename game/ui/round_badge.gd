class_name RoundBadge
extends PanelContainer
## Il numero del round dentro un cerchio, come nella bozza della battaglia.
##
## Godot non ha un contenitore tondo: il cerchio si ottiene da uno StyleBoxFlat
## con il raggio d'angolo pari a metà del lato. Va tenuto in sincrono con la
## dimensione, altrimenti diventa un quadrato con gli spigoli smussati.

const DIAMETRO := 96

var _numero: Label
var _etichetta: Label


func _init(round_number: int = 1, totali: int = 8) -> void:
	custom_minimum_size = Vector2(DIAMETRO, DIAMETRO)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var tondo := ThemeBuilder.box(Palette.SURFACE, Palette.ACCENT, DIAMETRO / 2, Palette.BORDER_WIDTH)
	add_theme_stylebox_override("panel", tondo)

	_etichetta = Ui.dim("ROUND", Palette.FONT_SMALL)
	_etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_numero = Ui.label("", Palette.FONT_HEADING, Palette.ACCENT)
	_numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	add_child(Ui.center(Ui.vbox([_etichetta, _numero], 0)))
	set_round(round_number, totali)


func set_round(round_number: int, totali: int) -> void:
	_numero.text = "%d/%d" % [round_number, totali]
