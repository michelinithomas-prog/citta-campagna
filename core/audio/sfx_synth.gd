class_name SfxSynth
extends RefCounted
## Genera effetti sonori a runtime, così il template ha feedback audio senza
## portarsi dietro nessun file.
##
##   Audio.sfx("click")   # usa questi suoni finché non metti i tuoi .ogg
##
## Il giorno della jam basta mettere game/audio/click.ogg e quel file vince
## automaticamente sul suono sintetico con lo stesso nome (vedi Audio.sfx).

enum Wave { SINE, SQUARE, TRIANGLE, SAW, NOISE }

const MIX_RATE := 22050


## Suono base: una nota che scivola da `freq_start` a `freq_end` mentre svanisce.
static func tone(
	freq_start: float,
	freq_end: float,
	duration: float,
	wave: Wave = Wave.SQUARE,
	decay: float = 8.0,
	volume: float = 0.35
) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var phase := 0.0

	for i in sample_count:
		var t := float(i) / MIX_RATE
		var progress := float(i) / maxf(float(sample_count), 1.0)
		var freq: float = lerpf(freq_start, freq_end, progress)
		phase += TAU * freq / MIX_RATE

		var value := 0.0
		match wave:
			Wave.SINE: value = sin(phase)
			Wave.SQUARE: value = 1.0 if sin(phase) >= 0.0 else -1.0
			Wave.TRIANGLE: value = asin(sin(phase)) * 2.0 / PI
			Wave.SAW: value = fposmod(phase, TAU) / PI - 1.0
			Wave.NOISE: value = rng.randf_range(-1.0, 1.0)

		# Attacco di 5 ms per non sentire il "clic" di inizio, poi decadimento.
		var attack: float = minf(t / 0.005, 1.0)
		var envelope: float = attack * exp(-t * decay)
		bytes.encode_s16(i * 2, int(clampf(value * envelope * volume, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Suoni pronti. Chiamare con un nome sconosciuto restituisce null.
static func preset(name: String) -> AudioStreamWAV:
	match name:
		"click": return tone(900.0, 700.0, 0.06, Wave.SQUARE, 30.0, 0.20)
		"hover": return tone(1400.0, 1400.0, 0.03, Wave.SINE, 40.0, 0.10)
		"confirm": return tone(600.0, 1200.0, 0.14, Wave.TRIANGLE, 12.0, 0.28)
		"cancel": return tone(500.0, 220.0, 0.14, Wave.SQUARE, 14.0, 0.22)
		"hit": return tone(320.0, 90.0, 0.16, Wave.SQUARE, 16.0, 0.35)
		"crit": return tone(500.0, 120.0, 0.24, Wave.SAW, 10.0, 0.38)
		"hurt": return tone(220.0, 70.0, 0.26, Wave.SAW, 9.0, 0.35)
		"coin": return tone(1000.0, 1600.0, 0.12, Wave.SQUARE, 14.0, 0.22)
		"buy": return tone(700.0, 1400.0, 0.10, Wave.TRIANGLE, 16.0, 0.25)
		"error": return tone(200.0, 150.0, 0.20, Wave.SQUARE, 10.0, 0.25)
		"level_up": return tone(500.0, 1500.0, 0.35, Wave.TRIANGLE, 5.0, 0.30)
		"win": return tone(600.0, 1800.0, 0.50, Wave.SINE, 3.5, 0.32)
		"lose": return tone(400.0, 80.0, 0.60, Wave.TRIANGLE, 4.0, 0.32)
		"whoosh": return tone(1.0, 1.0, 0.18, Wave.NOISE, 18.0, 0.18)
		"explosion": return tone(1.0, 1.0, 0.45, Wave.NOISE, 7.0, 0.30)
		"tick": return tone(1800.0, 1800.0, 0.02, Wave.SQUARE, 60.0, 0.12)
	return null


static func preset_names() -> Array[String]:
	return [
		"click", "hover", "confirm", "cancel", "hit", "crit", "hurt", "coin",
		"buy", "error", "level_up", "win", "lose", "whoosh", "explosion", "tick",
	]
