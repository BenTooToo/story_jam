extends Node
## 网页版（B 站 Toy）的平台层，自动加载为 Toy。桌面版也挂着，只是大部分功能直接跳过。
##
## - Toy JS SDK：经 bilibili/shell.html 里的 window.gameToy 调用。SDK 给的是 Promise，
##   GDScript 等不了，所以 JS 那边按名字存结果，这里每帧去问（call_toy）。
## - 手机：帧率封顶 60；画质「流畅」时网页只按游戏 2 倍分辨率渲染（shell.html 接管
##   devicePixelRatio），粒子也少放一点（particles）。
## - 长音频一律流式播放：网页版默认把每段声音完整解码进内存而且不释放，
##   几首 3～4 分钟的曲子就能把手机 App 撑到闪退。
## - 三位作者主页 / 介绍视频的跳转，和「喜欢的话可以关注我们」那行感谢语（thanks_text）。
##
## 不会因为没关注、没三连锁住任何内容（Toy 规定，违反会下架），这些只用来改一句感谢的话。
## SDK 只查得到玩家有没有关注这个 Toy 的上传者（小名是木木），查不到另外两位。

signal relation_changed

## 三位作者（名字 -> B 站 UID），按这个顺序显示。上传 Toy 的是小名是木木（AUTHOR_MID），
## 关注 / 三连状态查的都是这个号。
const AUTHORS := {"本2兔": "591702240", "小名是木木": "1876827674", "小高星": "117658614"}
const AUTHOR_MID := "1876827674"
## 两条线各自的作者，片尾卡片上突出显示
const ROUTE_AUTHORS := {"ben": ["本2兔"], "mumu": ["小名是木木", "小高星"]}
## 这个游戏的介绍视频。视频还没发就留空，「介绍视频」按钮自己会藏起来。
const VIDEO_BVID := ""
const MAX_FPS := 60
## 超过这么多秒的声音改成流式播放
const STREAM_LONGER_THAN := 10.0
## 画质「流畅」时，一次性粒子只放这么多
const SMOOTH_PARTICLES := 0.4

var smooth := false
## 关注 / 三连状态，ask_relation() 问回来之后才有意义
var following := false
var triple := false

var _waiting := {}   # key -> Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = MAX_FPS
	if is_web():
		get_tree().node_added.connect(_on_node_added)


func is_web() -> bool:
	return OS.has_feature("web")


## 手机（或平板）上的网页。shell.html 按 UA 判断，桌面版永远是 false。
func is_phone() -> bool:
	return is_web() and bool(JavaScriptBridge.eval("!!window.gamePhone", true))


## 「v1.0 · 10.09 21:30」这样的版本号，导出脚本写进 shell.html；桌面版和本地没导出时是空的。
func version() -> String:
	if not is_web():
		return ""
	var v := str(JavaScriptBridge.eval("window.gameVersion || ''", true))
	return "" if v.begins_with("__") else v


func set_smooth(on: bool) -> void:
	smooth = on
	if is_web():
		JavaScriptBridge.eval("window.gameSmooth = %s;" % ("true" if on else "false"), true)


## 一次性爆开的粒子：流畅模式只放 40%。
func particles(count: int) -> int:
	return maxi(1, int(count * SMOOTH_PARTICLES)) if smooth else count


# ---------- Toy SDK ----------

## body 是一段 JS 函数体，拿到 toy、返回 Promise；done 在之后某一帧收到
## {status = "ok", data} 或 {status = "error", error}。不在网页上就马上回 error。
func call_toy(key: String, body: String, done: Callable) -> void:
	if not is_web():
		done.call({status = "error", error = "not_web"})
		return
	_waiting[key] = done
	JavaScriptBridge.eval(
		"window.gameToy && window.gameToy.run('%s', function (toy) { %s });" % [key, body], true)


func _process(_delta: float) -> void:
	for key: String in _waiting.keys():
		var answer = JSON.parse_string(str(JavaScriptBridge.eval(
			"window.gameToy ? window.gameToy.get('%s') : 'null'" % key, true)))
		if not (answer is Dictionary):
			answer = {status = "error", error = "no_bridge"}
		if answer.get("status") == "loading":
			continue
		var done: Callable = _waiting[key]
		_waiting.erase(key)
		if done.is_valid():
			done.call(answer)


## 必须在点击 / 触摸的处理函数里直接调用（SDK 要用户手势）。
## B 站 App 里用 toy.navigate；别的地方新开标签页（网页端 navigate 会把整页带走，游戏就没了）。
func open_bilibili(type: String, id: String, url: String) -> void:
	if not is_web():
		OS.shell_open(url)
		return
	JavaScriptBridge.eval("""(function () {
		var tab = function () { window.open('%s', '_blank'); };
		if (/BiliApp/i.test(navigator.userAgent) && window.toy && typeof window.toy.navigate === 'function') {
			window.toy.navigate({ type: '%s', id: '%s' }).catch(tab);
		} else { tab(); }
	}());""" % [url, type, id], true)


func open_author_page(mid := AUTHOR_MID) -> void:
	open_bilibili("space", mid, "https://space.bilibili.com/" + mid)


func has_video() -> bool:
	return VIDEO_BVID != ""


func open_video() -> void:
	if has_video():
		open_bilibili("video", VIDEO_BVID, "https://www.bilibili.com/video/" + VIDEO_BVID)


## 问一次「关注了没、介绍视频三连了没」。两个接口都不弹授权窗，没登录就静默失败。
func ask_relation() -> void:
	var actions := "Promise.resolve(null)"
	if has_video():
		actions = "toy.getVideoUserActions({ videos: [{ bvid: '%s' }] }).catch(function () { return null; })" % VIDEO_BVID
	call_toy("relation", """return Promise.all([
			toy.getAuthorRelation().catch(function () { return null; }),
			%s,
		]).then(function (r) { return { relation: r[0], actions: r[1] }; });""" % actions,
		_on_relation)


func _on_relation(r: Dictionary) -> void:
	if r.get("status") != "ok" or not (r.get("data") is Dictionary):
		return
	var rel = r.data.get("relation")
	if rel is Dictionary and rel.get("status") == "ok" and rel.get("data") is Dictionary:
		following = bool(rel.data.get("isFollowing", false))
	var act = r.data.get("actions")
	if act is Dictionary and act.get("items") is Array and not act.items.is_empty():
		var it = act.items[0]
		if it is Dictionary and it.get("status") == "ok":
			triple = bool(it.get("liked", false)) and float(it.get("coinCount", 0)) > 0.0 \
				and bool(it.get("favorited", false))
	relation_changed.emit()


func thanks_text() -> String:
	if following and triple:
		return "谢谢你的关注和三连。"
	if following:
		return "谢谢你的关注。"
	return "喜欢的话，可以关注我们。"


# ---------- 长音频流式播放 ----------

func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		_stream_if_long(node)
		# 也有先挂进树、再塞 stream 的写法，下一帧再看一眼
		_stream_if_long.call_deferred(node)


func _stream_if_long(player: Node) -> void:
	if not is_instance_valid(player):
		return
	var s := player.get("stream") as AudioStream
	if s != null and s.get_length() > STREAM_LONGER_THAN:
		player.set("playback_type", AudioServer.PLAYBACK_TYPE_STREAM)
