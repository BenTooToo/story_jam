extends Node
## 存档，自动加载为 SaveData。只记几样永久的东西：达成过的结局、每首歌的最高分、画质设置，
## 还有开局前的关注卡片弹过没有。
## 剧情本身十分钟一局，不存中途进度。
##
## 本地存在 user://save.json（网页上是 IndexedDB）。网页版再同步一份到 Toy 云存储：
## B 站 App 的 WebView 闪退时可能丢掉 IndexedDB，玩家就白打了。
## - 启动时读云端合并：结局取并集，分数取两边的高者。
## - 合并完之前绝不往云端写，免得一份空存档把云端的覆盖掉；读失败 / 没登录就整局不写。
## - 只在关键节点写（打出结局、跳完一首），不要每帧写：Toy 的云存储全体玩家共享频率额度。

signal changed

const PATH := "user://save.json"
const CLOUD_KEY := "story_jam_save"

## 三个结局：木木线的和解，本2兔线的爱河 / 反胃
const ENDINGS: Array[String] = ["mumu", "ben_love", "ben_tragedy"]
## 排行榜：1～4 号榜是四首歌的最高分（得分），5 号榜是集齐了几个结局
const SONG_BOARDS: Array[String] = ["可爱的小曲", "不如跳舞", "秒針を噛む", "Levitating"]
const ENDINGS_BOARD := 5

var endings: Array[String] = []
var dance_best := {}          # 歌名 -> 最高分
## 画质：null = 没选过，按设备来（手机流畅、电脑标准）
var smooth = null
## 每个榜已经上报过的分数，同分不再报，省 Toy 的频率额度
var reported := {}            # "1" -> 分数
## 开局前的关注卡片弹过了（只弹一次）
var follow_prompted := false

var _cloud := "waiting"       # "waiting" | "ready" | "off"
var _cloud_dirty := false


func _ready() -> void:
	_load_local()
	Toy.set_smooth(Toy.is_phone() if smooth == null else bool(smooth))
	_cloud_load()


func has_ending(id: String) -> bool:
	return endings.has(id)


func add_ending(id: String) -> void:
	if endings.has(id):
		return
	endings.append(id)
	save()


## 跳完一首：记下最高分。返回是不是破了纪录。
func record_dance(song: String, score: int) -> bool:
	if score <= int(dance_best.get(song, 0)):
		return false
	dance_best[song] = score
	save()
	return true


func set_follow_prompted() -> void:
	follow_prompted = true
	_save_local()


func set_smooth(on: bool) -> void:
	smooth = on
	Toy.set_smooth(on)
	_save_local()


## 某个榜该报的分数（0 = 还没有成绩）
func board_score(board: int) -> int:
	if board == ENDINGS_BOARD:
		return endings.size()
	if board >= 1 and board <= SONG_BOARDS.size():
		return int(dance_best.get(SONG_BOARDS[board - 1], 0))
	return 0


func mark_reported(board: int, score: int) -> void:
	reported[str(board)] = score
	_save_local()


func needs_report(board: int) -> bool:
	var s := board_score(board)
	return s > 0 and s > int(reported.get(str(board), 0))


func save() -> void:
	_save_local()
	_cloud_save()
	changed.emit()


# ---------- 本地 ----------

func _load_local() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary):
		return
	_merge(data)
	if data.has("smooth") and data.smooth is bool:
		smooth = data.smooth
	if data.get("reported") is Dictionary:
		reported = data.reported
	follow_prompted = bool(data.get("follow_prompted", false))


func _save_local() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	var data := _progress()
	data.smooth = smooth
	data.reported = reported
	data.follow_prompted = follow_prompted
	file.store_string(JSON.stringify(data))


## 结局和分数（云端也只存这些，远小于 1024 字节）
func _progress() -> Dictionary:
	return {endings = endings, dance = dance_best}


## 把另一份进度并进来：结局取并集，分数取高者。返回有没有变。
func _merge(data: Dictionary) -> bool:
	var grew := false
	for id in data.get("endings", []):
		if ENDINGS.has(str(id)) and not endings.has(str(id)):
			endings.append(str(id))
			grew = true
	var dance = data.get("dance", {})
	if dance is Dictionary:
		for song in dance:
			var s := int(dance[song])   # JSON 的数字读回来是 float
			if s > int(dance_best.get(song, 0)):
				dance_best[song] = s
				grew = true
	return grew


# ---------- Toy 云存储 ----------

func _cloud_load() -> void:
	if not Toy.is_web():
		_cloud = "off"
		return
	Toy.call_toy("cloud_load", "return toy.getCloudStorage(['%s']);" % CLOUD_KEY, _on_cloud_loaded)


func _on_cloud_loaded(answer: Dictionary) -> void:
	if answer.get("status") != "ok":
		_cloud = "off"   # 没有 SDK / 没登录 / 失败：这一局都不碰云端
		return
	var stored = answer.get("data")
	var copy = null
	if stored is Dictionary and stored.has(CLOUD_KEY):
		copy = JSON.parse_string(str(stored[CLOUD_KEY]))
	var grew := copy is Dictionary and _merge(copy)
	_cloud = "ready"
	if grew:
		_save_local()
		changed.emit()
	# 云端没有、或者本地有云端没有的（比如本地先打了一局），都推上去
	if _cloud_dirty or not (copy is Dictionary) or not _covers(copy):
		_cloud_dirty = false
		_cloud_save()


## 这份进度是不是已经包含了本地的全部
func _covers(data: Dictionary) -> bool:
	var their_endings: Array = data.get("endings", [])
	for id in endings:
		if not their_endings.has(id):
			return false
	var their_dance = data.get("dance", {})
	if not (their_dance is Dictionary):
		return dance_best.is_empty()
	for song in dance_best:
		if int(dance_best[song]) > int(their_dance.get(song, 0)):
			return false
	return true


func _cloud_save() -> void:
	if not Toy.is_web() or _cloud == "off":
		return
	if _cloud == "waiting":
		_cloud_dirty = true
		return
	# 外面再套一层 stringify：变成 JS 的字符串字面量，原样塞进 setCloudStorage
	var value := JSON.stringify(JSON.stringify(_progress()))
	Toy.call_toy("cloud_save", "return toy.setCloudStorage({ %s: %s });" % [CLOUD_KEY, value],
		func(_a: Dictionary) -> void: pass)
