// Prototyp-Ozean fuer M1: Gerstner-artige Wellen aus drei Sinus-Lagen.
//
// Die Wellen werden in WELTKOORDINATEN berechnet. Dadurch bleibt das Meer
// ortsfest, auch wenn die Plane dem Schiff hinterherwandert - sonst wuerde
// die See mitschwimmen und man saehe die eigene Fahrt nicht.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.02, 0.10, 0.20);
uniform vec3 shallow_color : source_color = vec3(0.09, 0.34, 0.46);
uniform vec3 crest_color : source_color = vec3(0.55, 0.78, 0.84);

// Muessen mit world/ocean/ocean_waves.gd uebereinstimmen - sonst reitet das
// Schiff nicht auf den Wellen, die es sieht.
uniform float wave_height = 0.75;
uniform float wave_scale = 0.10;
uniform float wave_speed = 0.55;

// Von ocean.gd gesetzt. Bewusst nicht TIME: Die Spiellogik braucht dieselbe
// Uhr, um die Wasserhoehe unter dem Rumpf zu berechnen.
uniform float wave_time = 0.0;

// Weltfestes Gitternetz - macht Fahrt und Drift sichtbar. Fuer die fertige
// Optik spaeter auf 0.0 setzen.
uniform float grid_size = 30.0;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.07;

varying vec3 v_world;
varying float v_wave;

float swell(vec2 p, float t) {
	float w = sin(p.x * wave_scale + t) * 0.50;
	w += sin(p.y * wave_scale * 1.30 - t * 0.80) * 0.35;
	w += sin((p.x + p.y) * wave_scale * 0.70 + t * 1.40) * 0.25;
	w += sin((p.x - p.y) * wave_scale * 3.10 - t * 1.90) * 0.12;
	return w;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = wave_time * wave_speed;

	float h = swell(v_world.xz, t);
	VERTEX.y += h * wave_height;
	v_wave = h;

	// Normale aus finiten Differenzen, sonst bleibt die See flach beleuchtet.
	float e = 3.0;
	float hx = swell(v_world.xz + vec2(e, 0.0), t);
	float hz = swell(v_world.xz + vec2(0.0, e), t);
	vec3 tx = vec3(e, (hx - h) * wave_height, 0.0);
	vec3 tz = vec3(0.0, (hz - h) * wave_height, e);
	NORMAL = normalize(cross(tz, tx));
}

void fragment() {
	float crest = clamp(v_wave * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, crest);
	col = mix(col, crest_color, smoothstep(0.68, 1.0, crest) * 0.55);

	if (grid_strength > 0.0) {
		vec2 cell = v_world.xz / grid_size;
		vec2 d = abs(fract(cell - 0.5) - 0.5) / fwidth(cell);
		float line = 1.0 - min(min(d.x, d.y), 1.0);
		col = mix(col, crest_color, line * grid_strength);
	}

	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
