extends Node
## 音效 Autoload（程序合成）。
## v1：纯代码合成 sine + 简单 envelope，无 wav 资源。
## 未来替换真音色：只需改 _build_* 函数返回真 AudioStream，对外 API 不变。
##
## 频率定义（spec §14 T10：凡-灵-法-禁-秘 五级铛声）
## - 凡 220Hz / 灵 330Hz / 法 440Hz / 禁 550Hz / 秘 880Hz
## - 攻破嗡声 80Hz / 打听短铃 880Hz

const SAMPLE_RATE: int = 22050
const FORGE_FREQS: Array[float] = [220.0, 330.0, 440.0, 550.0, 880.0]
const BREACH_FREQ: float = 80.0
const INSPECT_FREQ: float = 880.0

var _player: AudioStreamPlayer = null
var _streams: Dictionary = {}  # name -> AudioStreamWAV


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)
	_streams[&"forge_0"] = _build_tone(FORGE_FREQS[0], 0.4, 0.6)
	_streams[&"forge_1"] = _build_tone(FORGE_FREQS[1], 0.45, 0.6)
	_streams[&"forge_2"] = _build_tone(FORGE_FREQS[2], 0.5, 0.65)
	_streams[&"forge_3"] = _build_tone(FORGE_FREQS[3], 0.6, 0.7)
	_streams[&"forge_4"] = _build_tone(FORGE_FREQS[4], 0.8, 0.75)  # 秘 最响
	_streams[&"breach"] = _build_tone(BREACH_FREQ, 0.6, 0.6)
	_streams[&"inspect"] = _build_tone(INSPECT_FREQ, 0.08, 0.45)


## 出炉音：tier 0..4 对应 凡/灵/法/禁/秘
func play_forge(tier: int) -> void:
	var t: int = clampi(tier, 0, 4)
	_play(StringName("forge_%d" % t))


func play_breach() -> void:
	_play(&"breach")


func play_inspect() -> void:
	_play(&"inspect")


func _play(name: StringName) -> void:
	if _player == null: return
	var s: AudioStreamWAV = _streams.get(name, null)
	if s == null: return
	_player.stream = s
	_player.play()


## 生成 sine + 线性 attack/decay envelope。
## freq 单位 Hz；duration 秒；volume 峰值 0..1
static func _build_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * duration)
	var attack_n: int = int(SAMPLE_RATE * 0.01)         # 10ms attack 防 click
	var release_n: int = int(SAMPLE_RATE * 0.05)        # 50ms release
	var data := PackedByteArray()
	data.resize(n * 2)  # 16bit mono
	var two_pi_f_over_sr: float = TAU * freq / float(SAMPLE_RATE)
	for i in n:
		var env: float = 1.0
		if i < attack_n:
			env = float(i) / float(max(1, attack_n))
		elif i > n - release_n:
			env = float(n - i) / float(max(1, release_n))
		var sample: float = sin(two_pi_f_over_sr * float(i)) * env * volume
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xff
		data[i * 2 + 1] = (s16 >> 8) & 0xff
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SAMPLE_RATE
	w.stereo = false
	w.data = data
	return w
