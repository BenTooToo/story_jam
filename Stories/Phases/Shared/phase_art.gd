class_name JamArt
extends RefCounted
## 三阶段玩法的美术素材登记表。
##
## 缺的素材统一登记在这里，代码只按 key 取图：
## - 素材存在  -> 直接画素材
## - 素材没到  -> 画一个中性灰占位形状（纯色，不做任何风格化）
##
## 所以美术到货后，只要把文件按下面的路径丢进 Assets/Branch/，
## 不用改任何玩法代码就会自动生效。
## 素材需求（尺寸 / 帧数 / 命名）见 Assets/Branch/素材需求.md。

const PATHS := {
	# 阶段一：扔物大战
	"投掷物1": "res://Assets/Branch/投掷物1.png",
	"投掷物2": "res://Assets/Branch/投掷物2.png",
	"投掷物3": "res://Assets/Branch/投掷物3.png",
	"掉落1分": "res://Assets/Branch/掉落物1分.png",
	"掉落3分": "res://Assets/Branch/掉落物3分.png",
	"掉落5分": "res://Assets/Branch/掉落物5分.png",
	"隔断": "res://Assets/Branch/隔断.png",
	# 阶段二：舞蹈对决
	"箭头": "res://Assets/Branch/箭头.png",
	# 阶段三：电梯怪兽
	"怪兽": "res://Assets/Branch/电梯怪兽.png",
	"齿轮": "res://Assets/Branch/齿轮.png",
	"冲击波": "res://Assets/Branch/冲击波.png",
	"落点预警": "res://Assets/Branch/落点预警.png",
	# 通用
	"眩晕星星": "res://Assets/Branch/眩晕星星.png",
	"命中特效": "res://Assets/Branch/命中特效.png",
}
## 占位统一用这个灰，方便一眼看出"这里还缺素材"
const PLACEHOLDER := Color(0.62, 0.62, 0.66)

static var _cache := {}


## 取素材；没有就返回 null。
static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var result: Texture2D = null
	var path: String = PATHS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		result = load(path)
	_cache[key] = result
	return result


static func has(key: String) -> bool:
	return tex(key) != null


## 还没到货的素材 key 列表。
static func missing() -> Array:
	var out := []
	for key: String in PATHS:
		if not has(key):
			out.append(key)
	return out


static func missing_report() -> String:
	var lack := missing()
	if lack.is_empty():
		return "素材齐了"
	return "缺 %d 个素材：%s" % [lack.size(), ", ".join(lack)]


## 以 at 为中心画一张素材；素材没到就画一个纯色圆占位。
static func draw_sprite(
	cv: CanvasItem,
	key: String,
	at: Vector2,
	height: float,
	rot := 0.0,
	modulate := Color.WHITE,
) -> void:
	var t := tex(key)
	if t == null:
		cv.draw_circle(at, height * 0.5, PLACEHOLDER * modulate)
		return
	var s := height / float(t.get_height())
	var w := float(t.get_width()) * s
	cv.draw_set_transform(at, rot, Vector2.ONE)
	cv.draw_texture_rect(t, Rect2(-w * 0.5, -height * 0.5, w, height), false, modulate)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 把素材铺满一个矩形；素材没到就填纯色占位。
static func draw_in_rect(cv: CanvasItem, key: String, rect: Rect2, modulate := Color.WHITE) -> void:
	var t := tex(key)
	if t == null:
		cv.draw_rect(rect, PLACEHOLDER * modulate)
		return
	cv.draw_texture_rect(t, rect, false, modulate)
