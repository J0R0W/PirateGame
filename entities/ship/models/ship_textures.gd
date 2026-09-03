## Prozedurale Texturen fuer Rumpf, Deck und Tuch.
##
## [b]Warum gerechnet und nicht gemalt[/b]: Im ganzen Projekt liegt keine
## einzige Bilddatei - Gelaende, Seekarte und Schiffe entstehen aus Zahlen. Eine
## Textur von der Platte waere das erste Bild, das jemand pflegen muesste, und
## sie liesse sich weder umfaerben noch nach Massstab strecken.
##
## [b]Warum ueberhaupt Texturen[/b]: Regel A11 sagt, das Licht traegt und nicht
## die Oberflaeche - sie verbietet aber nicht, dass ein Deck aus Planken besteht.
## Ohne Fugen ist eine Decksflaeche ein brauner Fleck, und zwar genau in der
## Aufsicht, in der man das Schiff im Hafen und beim Entern sieht.
##
## Deshalb sind alle Texturen [b]Graustufen und wirken multiplikativ[/b]: Die
## Farbe kommt weiter aus [Palette] ueber die Vertexfarben, die Textur nimmt an
## den Fugen nur Helligkeit weg. Damit bleibt Regel A3 unangetastet - hier steht
## kein einziger Farbton.
##
## [b]Die Kachel ist ein Meter.[/b] Alle UV-Koordinaten im Schiffsmodell sind in
## Metern angegeben; damit passt dieselbe Textur auf Rumpf, Deck und Aufbauten,
## ohne dass irgendwo ein Massstab nachgestellt werden muss.
class_name ShipTextures
extends RefCounted

## Kantenlaenge der Planken-Kachel in Pixeln.
const PLANK_PIXELS: int = 256
## Planken je Meter. Acht heisst 12,5 cm breite Planken - im Massstab des
## Spiels (die Karavelle ist hier 9,6 m lang statt 22) entspricht das den
## ueblichen 25 bis 30 cm an Deck.
const PLANKS_PER_METRE: int = 8
## Wie dunkel eine Fuge ist. Tiefer als 0,7 sieht der Rumpf gestreift aus
## statt beplankt.
const SEAM: float = 0.74
## Wie dunkel eine Stossfuge quer zur Planke ist. Schwaecher als die Laengsfuge:
## Sie liegt in der Planke, nicht zwischen zweien.
const BUTT: float = 0.86

## Kantenlaenge der Tuch-Kachel. Tuch hat keine harten Kanten, da reicht die
## halbe Aufloesung.
const CANVAS_PIXELS: int = 128
## Segelbahnen je Meter. Zwei heisst 50 cm breite Bahnen - historisch waeren es
## eher 25, aber dann steht ein neun Meter langer Lateiner voller Striche.
const PANELS_PER_METRE: int = 2
## Wie dunkel eine Naht im Tuch ist. Sehr schwach: Ein Segel lebt vom Bauch,
## nicht von der Naht.
const STITCH: float = 0.93

static var _planking: ImageTexture = null
static var _canvas: ImageTexture = null


## Beplankung fuer Rumpf, Deck und Aufbauten.
##
## Die Fugen laufen entlang der U-Achse, liegen also bei konstantem V. Wer die
## Textur benutzt, legt V quer zur Planke - laengs des Rumpfes um den Spant
## herum, quer ueber das Deck.
static func planking() -> ImageTexture:
	if _planking == null:
		_planking = _upload(_draw_planking())
	return _planking


## Segeltuch: Bahnen und ein sehr feines Gewebe.
##
## Dieselbe Ausrichtung wie bei der Beplankung - Naehte bei konstantem V.
static func canvas() -> ImageTexture:
	if _canvas == null:
		_canvas = _upload(_draw_canvas())
	return _canvas


## Haengt eine Textur so an ein Material, dass ein UV-Meter eine Kachel ist.
##
## Anisotrop gefiltert, weil ein Deck fast immer schraeg im Bild steht: Ohne das
## verschmieren die Fugen zu einem grauen Schleier, sobald man nicht senkrecht
## darauf sieht.
static func apply(material: StandardMaterial3D, texture: ImageTexture) -> void:
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true


# --- Gezeichnet -------------------------------------------------------------

static func _draw_planking() -> Image:
	var size := PLANK_PIXELS
	var image := Image.create_empty(size, size, true, Image.FORMAT_RGB8)

	# Fester Seed: Die Textur muss in jedem Lauf dieselbe sein, sonst waeren
	# zwei Aufnahmen desselben Schiffs nicht vergleichbar.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711

	var band := float(size) / float(PLANKS_PER_METRE)

	# Je Planke ein eigener Grundton und eine eigene Stossfuge. Ohne das liegt
	# ueber dem Rumpf ein Muster statt einer Beplankung - das Auge findet die
	# Wiederholung sofort.
	var tones := PackedFloat32Array()
	var butts := PackedFloat32Array()
	for i in PLANKS_PER_METRE:
		tones.append(1.0 + rng.randf_range(-0.05, 0.05))
		butts.append(rng.randf() * float(size))

	for y in size:
		var index := int(float(y) / band) % PLANKS_PER_METRE
		var value: float = tones[index]

		# Abstand zur naechsten Laengsfuge, in Pixeln.
		var edge := fmod(float(y), band)
		var gap := minf(edge, band - edge)
		if gap < 1.6:
			value *= lerpf(SEAM, 1.0, gap / 1.6)

		var butt: float = butts[index]
		for x in size:
			var shade := value
			# Stossfuge: der Stoss zweier Planken in Laengsrichtung.
			var run := absf(fmod(float(x) - butt + float(size) * 1.5, float(size)) - float(size) * 0.5)
			if run < 1.2:
				shade *= lerpf(BUTT, 1.0, run / 1.2)
			# Maserung. So schwach, dass man sie einzeln nicht sieht - sie
			# nimmt der Flaeche nur das Sterile.
			shade += rng.randf_range(-0.012, 0.012)
			image.set_pixel(x, y, Palette.grey(shade))

	image.generate_mipmaps()
	return image


static func _draw_canvas() -> Image:
	var size := CANVAS_PIXELS
	var image := Image.create_empty(size, size, true, Image.FORMAT_RGB8)

	var band := float(size) / float(PANELS_PER_METRE)

	for y in size:
		var edge := fmod(float(y), band)
		var gap := minf(edge, band - edge)
		var seam := 1.0
		if gap < 1.4:
			seam = lerpf(STITCH, 1.0, gap / 1.4)

		for x in size:
			# Gewebe: zwei feine Wellen ueber Kreuz. Kein Rauschen - Tuch ist
			# gewebt und damit regelmaessig, Holz ist gewachsen und damit nicht.
			var weave := 1.0 \
				+ sin(float(x) * PI * 0.5) * 0.008 \
				+ sin(float(y) * PI * 0.5) * 0.008
			image.set_pixel(x, y, Palette.grey(seam * weave))

	image.generate_mipmaps()
	return image


static func _upload(image: Image) -> ImageTexture:
	return ImageTexture.create_from_image(image)
