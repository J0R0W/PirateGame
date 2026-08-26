## Adaptive Musik: haelt mehrere Layer bereit und blendet zwischen Stimmungen.
##
## Geruest fuer M7. Aufrufe sind ab sofort gefahrlos moeglich - sie tun nur
## noch nichts, solange keine Streams zugewiesen sind.
extends Node

enum Mood { CALM, TENSE, COMBAT, PORT }

const FADE_DURATION: float = 1.5

var current_mood: Mood = Mood.CALM

## Mood -> AudioStreamPlayer. Wird in M7 mit echten Tracks gefuellt.
var _players: Dictionary = {}


func _ready() -> void:
	for mood: Mood in Mood.values():
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -80.0
		add_child(player)
		_players[mood] = player


## Blendet auf eine andere Stimmung ueber.
func set_mood(mood: Mood) -> void:
	if mood == current_mood:
		return
	var previous := current_mood
	current_mood = mood

	_fade_to(_players.get(previous), -80.0)
	var next: AudioStreamPlayer = _players.get(mood)
	if next != null and next.stream != null:
		if not next.playing:
			next.play()
		_fade_to(next, 0.0)


func _fade_to(player: AudioStreamPlayer, target_db: float) -> void:
	if player == null:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, FADE_DURATION)
