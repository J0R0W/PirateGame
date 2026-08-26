## Die Bausteine der Hafenbildschirme.
##
## Markt und Werft bauen ihre Oberflaeche im Code auf, nicht als .tscn: Eine
## Marktliste hat je Ware sieben Felder, die von Hand gepflegte Szene waere
## laenger als das Skript und muesste bei jeder neuen Ware angefasst werden.
##
## Damit beide Bildschirme gleich aussehen, entstehen Beschriftungen und
## Schaltflaechen hier - und nur hier greift die Palette in die Oberflaeche.
class_name PortWidgets
extends RefCounted


static func label(content: String, color: Color, size: int) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_color_override("font_color", color)
	node.add_theme_font_size_override("font_size", size)
	return node


## Rechtsbuendige Zahl mit fester Breite - Spalten sollen fluchten.
static func number(width: int) -> Label:
	var node := label("0", Palette.HUD_TEXT, 15)
	node.custom_minimum_size.x = width
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return node


## Flache Schaltflaeche: nur Text, kein Kasten - wie das HUD auf See.
static func button(content: String, size: int = 14) -> Button:
	var node := Button.new()
	node.text = content
	node.flat = true
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_color_override("font_color", Palette.MUTED)
	node.add_theme_color_override("font_hover_color", Palette.PARCHMENT)
	node.add_theme_color_override("font_pressed_color", Palette.BRASS)
	node.add_theme_color_override("font_disabled_color", Palette.fade(Palette.MUTED, 0.35))
	node.add_theme_font_size_override("font_size", size)
	return node


static func paint(node: Label, color: Color) -> void:
	node.add_theme_color_override("font_color", color)
