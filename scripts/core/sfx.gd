## Autoload "Sfx": global audio service.
## Purpose: plays procedurally synthesised retro sound effects (ported 1:1 from the WebAudio
## oscillator recipes of the web version), so the project ships without audio assets.
## Lifetime: whole application. Holds no gameplay state; safe to call from any scene.
class_name SfxPlayer
extends Node

enum Wave { SQUARE, TRIANGLE, SAW }

const MIX_RATE: int = 22050
const VOICES: int = 8
## WebAudio gains were ~0.05; scale into a useful PCM range.
const GAIN_SCALE: float = 4.0

class Tone:
	var delay: float
	var freq: float
	var duration: float
	var wave: int
	var volume: float
	var slide_to: float

	func _init(p_delay: float, p_freq: float, p_duration: float, p_wave: int, p_volume: float, p_slide_to: float = 0.0) -> void:
		delay = p_delay
		freq = p_freq
		duration = p_duration
		wave = p_wave
		volume = p_volume
		slide_to = p_slide_to

@export var volume_db: float = -3.0
var muted: bool = false

var _cache: Dictionary[StringName, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

func _ready() -> void:
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)

## Plays the effect [param id] (jump, djump, dash, coin, hurt, boom, shot, place, clear, over).
func play(id: StringName) -> void:
	if muted or _players.is_empty():
		return
	var stream: AudioStreamWAV = _get_stream(id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = stream
	player.play()

func _get_stream(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var tones: Array[Tone] = _recipe(id)
	if tones.is_empty():
		push_warning("Sfx: unknown effect '%s'" % id)
		return null
	var stream: AudioStreamWAV = _render(tones)
	_cache[id] = stream
	return stream

func _recipe(id: StringName) -> Array[Tone]:
	var t: Array[Tone] = []
	match id:
		&"jump": t.append(Tone.new(0.0, 340.0, 0.14, Wave.SQUARE, 0.06, 620.0))
		&"djump": t.append(Tone.new(0.0, 480.0, 0.16, Wave.TRIANGLE, 0.07, 820.0))
		&"dash": t.append(Tone.new(0.0, 180.0, 0.18, Wave.SAW, 0.05, 720.0))
		&"coin":
			t.append(Tone.new(0.0, 880.0, 0.07, Wave.SQUARE, 0.05))
			t.append(Tone.new(0.06, 1320.0, 0.10, Wave.SQUARE, 0.05))
		&"hurt": t.append(Tone.new(0.0, 300.0, 0.30, Wave.SAW, 0.08, 70.0))
		&"boom":
			t.append(Tone.new(0.0, 120.0, 0.5, Wave.SAW, 0.12, 40.0))
			t.append(Tone.new(0.06, 60.0, 0.4, Wave.SQUARE, 0.08, 30.0))
		&"shot": t.append(Tone.new(0.0, 210.0, 0.09, Wave.SQUARE, 0.045, 90.0))
		&"place":
			t.append(Tone.new(0.0, 620.0, 0.07, Wave.TRIANGLE, 0.06))
			t.append(Tone.new(0.07, 880.0, 0.10, Wave.TRIANGLE, 0.06))
		&"clear":
			var notes: PackedFloat32Array = [523.0, 659.0, 784.0, 1046.0]
			for i: int in notes.size():
				t.append(Tone.new(i * 0.11, notes[i], 0.22, Wave.TRIANGLE, 0.07))
		&"shield":
			t.append(Tone.new(0.0, 420.0, 0.22, Wave.TRIANGLE, 0.07, 900.0))
			t.append(Tone.new(0.08, 660.0, 0.22, Wave.TRIANGLE, 0.05, 1200.0))
		&"block": t.append(Tone.new(0.0, 1400.0, 0.06, Wave.SQUARE, 0.035, 700.0))
		&"wave":
			t.append(Tone.new(0.0, 900.0, 0.35, Wave.SAW, 0.06, 120.0))
			t.append(Tone.new(0.02, 110.0, 0.45, Wave.SQUARE, 0.06, 40.0))
		&"sweep":
			t.append(Tone.new(0.0, 70.0, 0.9, Wave.SAW, 0.10, 35.0))
			var rise: PackedFloat32Array = [392.0, 523.0, 659.0, 784.0, 1046.0, 1318.0]
			for i: int in rise.size():
				t.append(Tone.new(0.12 + i * 0.09, rise[i], 0.25, Wave.TRIANGLE, 0.06))
		&"upgrade":
			var up: PackedFloat32Array = [660.0, 880.0, 1175.0]
			for i: int in up.size():
				t.append(Tone.new(i * 0.07, up[i], 0.14, Wave.SQUARE, 0.045))
		&"over":
			var notes: PackedFloat32Array = [440.0, 349.0, 262.0]
			for i: int in notes.size():
				t.append(Tone.new(i * 0.16, notes[i], 0.30, Wave.SAW, 0.07))
	return t

func _render(tones: Array[Tone]) -> AudioStreamWAV:
	var length: float = 0.0
	for tone: Tone in tones:
		length = maxf(length, tone.delay + tone.duration)
	var count: int = int(ceil(length * MIX_RATE)) + 1
	var mix := PackedFloat32Array()
	mix.resize(count)
	for tone: Tone in tones:
		var start: int = int(tone.delay * MIX_RATE)
		var n: int = int(tone.duration * MIX_RATE)
		var phase: float = 0.0
		var end_gain: float = 0.0001 / maxf(tone.volume, 0.0001)
		for i: int in n:
			var k: float = float(i) / float(n)
			var f: float = tone.freq
			if tone.slide_to > 0.0:
				f = tone.freq * pow(maxf(40.0, tone.slide_to) / tone.freq, k)
			phase = fmod(phase + f / MIX_RATE, 1.0)
			var s: float
			match tone.wave:
				Wave.SQUARE: s = 1.0 if phase < 0.5 else -1.0
				Wave.TRIANGLE: s = 4.0 * absf(phase - 0.5) - 1.0
				_: s = 2.0 * phase - 1.0
			var idx: int = start + i
			if idx < count:
				mix[idx] += s * tone.volume * GAIN_SCALE * pow(end_gain, k)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
