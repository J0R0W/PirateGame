## Die Wellenformel - einmal definiert, von Shader und Spiellogik geteilt.
##
## Der Shader zeichnet die See, das Schiff muss darauf reiten. Beide muessen
## exakt dieselbe Hoehe berechnen, sonst schwebt oder versinkt das Schiff.
## Deshalb steht die Formel hier, und ocean.gdshader spiegelt sie Zeile fuer
## Zeile. Wird eine Konstante hier geaendert, muss der Shader mitgezogen werden.
##
## Auch die Zeit ist geteilt: ocean.gd schiebt time_now() als Uniform in den
## Shader, statt dort TIME zu benutzen - sonst laufen beide auseinander.
class_name OceanWaves
extends RefCounted

const WAVE_HEIGHT: float = 0.75
const WAVE_SCALE: float = 0.10
const WAVE_SPEED: float = 0.55


static func time_now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## Rohe Duenung aus vier Lagen mit 20 bis 90 Metern Wellenlaenge.
## Summe der Amplituden ist 1.22.
static func _swell(x: float, z: float, t: float) -> float:
	var w := sin(x * WAVE_SCALE + t) * 0.50
	w += sin(z * WAVE_SCALE * 1.30 - t * 0.80) * 0.35
	w += sin((x + z) * WAVE_SCALE * 0.70 + t * 1.40) * 0.25
	w += sin((x - z) * WAVE_SCALE * 3.10 - t * 1.90) * 0.12
	return w


## Wasserhoehe an einem Weltpunkt.
static func height_at(x: float, z: float, t: float) -> float:
	return _swell(x, z, t * WAVE_SPEED) * WAVE_HEIGHT
