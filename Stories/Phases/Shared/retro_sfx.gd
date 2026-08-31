class_name JamSfx
extends RefCounted
## 程序化 8-bit 音效：不依赖任何素材文件，代码里现做现放。

const RATE := 22050


## 生成一个从 freq_from 滑到 freq_to 的短促方波感提示音。
static func blip(freq_from: float, freq_to: float, dur: float, vol := 0.5) -> AudioStreamWAV:
	var frames := maxi(int(RATE * dur), 8)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / float(frames)
		var freq := lerpf(freq_from, freq_to, t)
		phase += TAU * freq / RATE
		var env := 1.0 - t
		var sample := clampf(sin(phase) * env * vol, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	return _wrap(data)


## 生成一段衰减的噪声，用来当撞击 / 怪吼。
static func noise(dur: float, vol := 0.5) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var frames := maxi(int(RATE * dur), 8)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(frames)
		var env := (1.0 - t) * (1.0 - t)
		var sample := rng.randf_range(-1.0, 1.0) * env * vol
		data.encode_s16(i * 2, int(sample * 32767.0))
	return _wrap(data)


## 挂一个一次性的播放器到 host 下，播完自动清理。
static func play(host: Node, stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
