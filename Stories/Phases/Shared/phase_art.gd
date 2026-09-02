class_name JamArt
extends RefCounted
## 三阶段玩法的美术素材登记表。
##
## 代码不直接写素材路径，一律按 key 来取：
## - 素材存在  -> 直接画素材
## - 素材没到  -> 画一个中性灰占位形状（纯色，不做任何风格化）
##
## 素材换名字或补新素材，只改这个文件，玩法代码不用动。
## 还缺的素材见 Assets/Branch/素材需求.md。

## 可以互相扔、也会从空中掉落的物品。
## - rect：素材里真正有画面的区域（马桶、可乐罐画布带透明边，要裁掉才好定位）
## - size：屏幕上的最长边像素。基准是和角色同一套缩放（0.34），
##   小文具兜底到 14px 免得看不见，最大压到 38px。角色身高 84px 作参照。
## - tier：掉落时的分值，按大小给：文具 1 分 / 随身物 3 分 / 大件 5 分
const ITEMS := [
	{name = "钢笔A", path = "res://Assets/Branch/pen 1_副本.png", rect = Rect2(0, 0, 3, 26), size = 14.0, tier = 1},
	{name = "钢笔B", path = "res://Assets/Branch/pen 2_副本.png", rect = Rect2(0, 0, 3, 26), size = 14.0, tier = 1},
	{name = "笔袋", path = "res://Assets/Branch/pencil case_副本.png", rect = Rect2(0, 0, 33, 9), size = 14.0, tier = 1},
	{name = "笔盒", path = "res://Assets/Branch/pencil pack_副本.png", rect = Rect2(0, 0, 42, 11), size = 14.3, tier = 1},
	{name = "课本", path = "res://Assets/Branch/book 1_副本.png", rect = Rect2(0, 0, 17, 25), size = 14.0, tier = 1},
	{name = "水瓶A", path = "res://Assets/Branch/water bottle 1_副本.png", rect = Rect2(0, 0, 15, 40), size = 14.0, tier = 3},
	{name = "水瓶B", path = "res://Assets/Branch/water bottle 2_副本.png", rect = Rect2(0, 0, 10, 36), size = 14.0, tier = 3},
	{name = "水瓶C", path = "res://Assets/Branch/water bottle 3_副本.png", rect = Rect2(0, 0, 15, 39), size = 14.0, tier = 3},
	{name = "可乐罐", path = "res://Assets/Branch/Subject UI14_副本.png", rect = Rect2(32, 15, 61, 108), size = 20.0, tier = 3},   # 画得比马桶还高，按饮料罐压小
	{name = "书筐", path = "res://Assets/Branch/book basket 2_副本.png", rect = Rect2(9, 5, 57, 83), size = 28.2, tier = 3},
	{name = "水桶", path = "res://Assets/Branch/bucket_副本.png", rect = Rect2(6, 5, 90, 93), size = 31.6, tier = 5},
	{name = "凳子", path = "res://Assets/Branch/chair_副本.png", rect = Rect2(15, 11, 65, 96), size = 32.6, tier = 5},
	{name = "扫帚", path = "res://Assets/Branch/broom_副本.png", rect = Rect2(2, 11, 51, 115), size = 38.0, tier = 5},
	{name = "马桶", path = "res://Assets/Branch/toilet_副本.png", rect = Rect2(31, 9, 68, 109), size = 37.1, tier = 5},
]

## 单张的素材。带 rect 的表示素材画布有透明边，只画里面那块。
const PATHS := {
	"绿箭头": {path = "res://Assets/Branch/绿箭头.png", rect = Rect2(42, 11, 48, 89)},
	"红箭头": {path = "res://Assets/Branch/红箭头.png", rect = Rect2(42, 10, 48, 93)},
	# 以下还没到货，先用中性灰占位
	"怪兽": {path = "res://Assets/Branch/电梯怪兽.png", rect = Rect2()},
	"齿轮": {path = "res://Assets/Branch/齿轮.png", rect = Rect2()},
	"冲击波": {path = "res://Assets/Branch/冲击波.png", rect = Rect2()},
	"落点预警": {path = "res://Assets/Branch/落点预警.png", rect = Rect2()},
	"眩晕星星": {path = "res://Assets/Branch/眩晕星星.png", rect = Rect2()},
	"命中特效": {path = "res://Assets/Branch/命中特效.png", rect = Rect2()},
	"隔断": {path = "res://Assets/Branch/隔断.png", rect = Rect2()},
}
## 占位统一用这个灰，方便一眼看出"这里还缺素材"
const PLACEHOLDER := Color(0.62, 0.62, 0.66)

static var _cache := {}


static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var result: Texture2D = null
	var entry: Dictionary = PATHS.get(key, {})
	var path: String = entry.get("path", "")
	if path != "" and ResourceLoader.exists(path):
		result = load(path)
	_cache[key] = result
	return result


static func has(key: String) -> bool:
	return tex(key) != null


## 素材里真正有画面的区域；没登记就用整张图。
static func _content_rect(t: Texture2D, declared: Rect2) -> Rect2:
	if declared.size.x > 0.0 and declared.size.y > 0.0:
		return declared
	return Rect2(Vector2.ZERO, t.get_size())


## 还没到货的素材 key 列表。
static func missing() -> Array:
	var out := []
	for key: String in PATHS:
		if not has(key):
			out.append(key)
	for item: Dictionary in ITEMS:
		if not ResourceLoader.exists(item.path):
			out.append(item.name)
	return out


static func missing_report() -> String:
	var lack := missing()
	if lack.is_empty():
		return "素材齐了"
	return "缺 %d 个素材：%s" % [lack.size(), ", ".join(lack)]


## 以 at 为中心画一张素材，height 是屏幕上的高度；没到货就画纯色圆占位。
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
	var src := _content_rect(t, PATHS[key].rect)
	var s := height / src.size.y
	var w := src.size.x * s
	cv.draw_set_transform(at, rot, Vector2.ONE)
	cv.draw_texture_rect_region(t, Rect2(-w * 0.5, -height * 0.5, w, height), src, modulate)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 把素材铺满一个矩形；素材没到就填纯色占位。
static func draw_in_rect(cv: CanvasItem, key: String, rect: Rect2, modulate := Color.WHITE) -> void:
	var t := tex(key)
	if t == null:
		cv.draw_rect(rect, PLACEHOLDER * modulate)
		return
	cv.draw_texture_rect_region(t, rect, _content_rect(t, PATHS[key].rect), modulate)


# ---------- 物品 ----------

static func item_count() -> int:
	return ITEMS.size()


## 随机挑一件；tier 传 0 表示不限分值。
static func random_item(rng: RandomNumberGenerator, tier := 0) -> int:
	var pool := []
	for i in ITEMS.size():
		if tier == 0 or int(ITEMS[i].tier) == tier:
			pool.append(i)
	if pool.is_empty():
		return 0
	return pool[rng.randi_range(0, pool.size() - 1)]


static func item(index: int) -> Dictionary:
	return ITEMS[clampi(index, 0, ITEMS.size() - 1)]


## 这件物品在屏幕上实际占的宽高（最长边缩到 size，短边按比例）。
static func item_screen_size(index: int) -> Vector2:
	var it := item(index)
	var src: Rect2 = it.rect
	var s: float = float(it.size) / maxf(src.size.x, src.size.y)
	return src.size * s


## 以 at 为中心画一件物品，按登记表里的尺寸；素材没到就画纯色圆占位。
static func draw_item(
	cv: CanvasItem,
	index: int,
	at: Vector2,
	rot := 0.0,
	modulate := Color.WHITE,
	scale_mul := 1.0,
) -> void:
	var it := item(index)
	var size: float = float(it.size) * scale_mul
	var key := "item:%d" % index
	var t: Texture2D = null
	if _cache.has(key):
		t = _cache[key]
	else:
		if ResourceLoader.exists(it.path):
			t = load(it.path)
		_cache[key] = t
	if t == null:
		cv.draw_circle(at, size * 0.5, PLACEHOLDER * modulate)
		return
	var src: Rect2 = it.rect
	# 最长边缩到 size，短边按比例
	var s: float = size / maxf(src.size.x, src.size.y)
	var w: float = src.size.x * s
	var h: float = src.size.y * s
	cv.draw_set_transform(at, rot, Vector2.ONE)
	cv.draw_texture_rect_region(t, Rect2(-w * 0.5, -h * 0.5, w, h), src, modulate)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
