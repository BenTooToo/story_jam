# Story Jam 对话系统使用手册

## 镜头控制函数

- `follow_camera(target: Node2D, zoom_amount: float = 1.35, offset: Vector2 = Vector2(0, -30)) -> void`：设置持续跟随对象；镜头会在每一帧更新位置和缩放。
- `move_camera(target_position: Vector2, zoom_amount: float = 1.0, duration: float = 0.5) -> Tween`：将镜头平滑移动到指定世界坐标，同时调整缩放；新的镜头移动会终止尚未完成的旧移动。
- `reset_camera(duration: float = 0.5) -> Tween`：退出跟随模式，将镜头平滑恢复到屏幕中心 `(320, 180)` 和默认缩放 `1.0`。

本目录保存项目的全局对话系统。对话系统已经在 `project.godot` 中注册为
Autoload，名称为 `Dialogue`，因此任意场景脚本都可以直接调用：

```gdscript
await Dialogue.entree(...)
```

`Dialogue` 不是矩阵（Matrix）、数组或对话内容文件。它是 Godot 的**全局单例
对象**：`project.godot` 会在游戏启动时自动创建它，并保证切换场景后它仍然存在。
可以把它理解为一个全局“对话服务”。代码中的 `Dialogue.entree()` 表示：调用
全局对话服务 `Dialogue` 上的 `entree()` 函数。

`Dialogue` 中还保存了角色编号对照表 `Character` 和表情编号对照表
`ExpressionState`。枚举名称本质上仍然是数字，只是更容易阅读。

对话正文使用 Godot 的 `RichTextLabel` 显示，支持 BBCode、逐字显示、角色头像、
表情状态和选项。调用者只负责提供数据，不需要操作对话框节点。

## 目录结构

```text
Stories/Shared/Dialogue/
├── dialogue_manager.gd  # 全局入口、角色/表情枚举、调用排队
├── dialogue_box.tscn    # 对话框 UI 场景
├── dialogue_box.gd      # 逐字显示、输入、头像和选项逻辑
└── README.md            # 本手册
```

## 最小调用示例

```gdscript
await Dialogue.entree(
	Dialogue.Character.NPC0,
	Dialogue.ExpressionState.SPEAKING,
	"我们已经到了十六层。",
)
```

必须使用 `await`。一句对话只有在玩家看完并确认后才会返回；使用 `await` 可以
保证下一句不会提前出现。

连续对话示例：

```gdscript
await Dialogue.entree(
	Dialogue.Character.NPC0,
	Dialogue.ExpressionState.SPEAKING,
	"电梯停下了。",
)

await Dialogue.entree(
	Dialogue.Character.NPC1,
	Dialogue.ExpressionState.SPEAKING,
	"但这里不是一楼。",
)
```

## `entree()` 完整格式

函数定义：

```gdscript
func entree(
	character_id: int,
	expression_id: int,
	dialogue_text: String,
	options: Array[String] = [],
) -> int
```

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `character_id` | `int` | 是 | 说话角色编号，推荐使用 `Dialogue.Character` 枚举 |
| `expression_id` | `int` | 是 | 头像状态，推荐使用 `Dialogue.ExpressionState` 枚举 |
| `dialogue_text` | `String` | 是 | 对话正文，可以包含 RichTextLabel BBCode |
| `options` | `Array[String]` | 否 | 选项列表；空数组代表没有选项 |

参数顺序固定为：

```text
角色编号 → 表情编号 → 对话正文 → 选项列表
```

返回值：

| 返回值 | 意义 |
| --- | --- |
| `-1` | 当前对话没有选项，玩家确认后结束 |
| `0` | 玩家选择第一个选项 |
| `1` | 玩家选择第二个选项 |
| `2` | 玩家选择第三个选项，以此类推 |

## 角色编号

推荐使用枚举名称：

```gdscript
Dialogue.Character.NPC0      # 数值 0，头像在左侧
Dialogue.Character.NPC1      # 数值 1，头像在右侧
Dialogue.Character.NARRATOR  # 数值 2，不显示头像
```

以下两种调用本质上完全相同：

```gdscript
await Dialogue.entree(0, 1, "我们到了。")
```

```gdscript
await Dialogue.entree(
	Dialogue.Character.NPC0,
	Dialogue.ExpressionState.SPEAKING,
	"我们到了。",
)
```

旁白示例：

```gdscript
await Dialogue.entree(
	Dialogue.Character.NARRATOR,
	Dialogue.ExpressionState.NORMAL,
	"电梯里只剩下机械运转的声音。",
)
```

## 表情编号

Godot 4.7 已经有一个名为 `Expression` 的原生类，所以本项目使用
`ExpressionState` 作为表情枚举名称。

当前可用状态：

```gdscript
Dialogue.ExpressionState.NORMAL    # 数值 0，普通头像
Dialogue.ExpressionState.SPEAKING  # 数值 1，说话头像
```

当前素材映射：

| 角色 | `NORMAL` | `SPEAKING` |
| --- | --- | --- |
| NPC0 | `Assets/ROMART/npc0.png` | 闭嘴/说话头像循环 |
| NPC1 | `Assets/ROMART/npc1.png` | 闭嘴/说话头像循环 |

以后增加生气、悲伤、害怕等头像时，可以扩展 `ExpressionState` 和头像映射，
不需要修改 `entree()` 的函数参数。

## 选项格式

选项必须是 `Array[String]`，不要把所有选项写进一个用逗号分隔的字符串。

```gdscript
var selected := await Dialogue.entree(
	Dialogue.Character.NPC1,
	Dialogue.ExpressionState.SPEAKING,
	"现在应该怎么办？",
	[
		"打开电梯门。",
		"继续等待。",
		"按下紧急按钮。",
	],
)

match selected:
	0:
		print("玩家选择开门")
	1:
		print("玩家选择等待")
	2:
		print("玩家选择紧急按钮")
```

选项目前使用普通 `Button`，所以选项字符串不解析 BBCode。BBCode 只用于
`dialogue_text` 对话正文。

## 常用 BBCode 格式

BBCode 的基本写法：

```text
[标签]需要改变格式的文字[/标签]
```

| 效果 | 格式 | 示例 |
| --- | --- | --- |
| 粗体 | `[b]文字[/b]` |
| 斜体 | `[i]文字[/i]` |
| 下划线 | `[u]文字[/u]` |
| 删除线 | `[s]文字[/s]` |
| 文字颜色 | `[color=颜色]文字[/color]` | `[color=#ff4040]危险[/color]` |
| 背景颜色 | `[bgcolor=颜色]文字[/bgcolor]` | `[bgcolor=#803030]警告[/bgcolor]` |
| 字号 | `[font_size=大小]文字[/font_size]` | `[font_size=24]停下！[/font_size]` |
| 描边大小 | `[outline_size=大小]文字[/outline_size]` | `[outline_size=2]门[/outline_size]` |
| 描边颜色 | `[outline_color=颜色]文字[/outline_color]` | `[outline_color=black]门[/outline_color]` |
| 换行 | `[br]` | `第一行[br]第二行` |
| 居中 | `[center]文字[/center]` |

颜色可以使用名称或十六进制：

```text
[color=red]红色[/color]
[color=#ff4040]红色[/color]
[color=#ff404080]半透明红色[/color]
```

多个格式可以嵌套：

```text
[b][color=#ff4040]危险[/color][/b]
```

## Godot 自带的六种动态文字效果

### 1. 脉冲 `pulse`

让文字不断改变透明度和颜色，适合提示、警告或心跳感。

```text
[pulse freq=1.0 color=#ffffff40 ease=-2.0]忽明忽暗[/pulse]
```

- `freq`：速度，越大越快。
- `color`：变化到的目标颜色。
- `ease`：缓动强度。

### 2. 波浪 `wave`

让文字上下波动。

```text
[wave amp=20.0 freq=5.0 connected=1]上下波动[/wave]
```

- `amp`：上下移动幅度。
- `freq`：波动速度。
- `connected`：通常保持 `1`。

### 3. 旋转 `tornado`

让每个字围绕原位置旋转移动。

```text
[tornado radius=6.0 freq=1.0 connected=1]旋转文字[/tornado]
```

- `radius`：旋转半径。
- `freq`：旋转速度，负数表示反向。
- `connected`：通常保持 `1`。

### 4. 颤抖 `shake`

让文字快速抖动，适合恐惧、愤怒和强烈警告。

```text
[shake rate=20.0 level=5 connected=1]不要开门！[/shake]
```

- `rate`：颤抖速度。
- `level`：颤抖强度。
- `connected`：通常保持 `1`。

### 5. 渐隐 `fade`

让一段文字从指定位置开始逐渐消失。

```text
[fade start=4 length=14]逐渐消失的文字[/fade]
```

- `start`：从第几个字符开始渐隐。
- `length`：渐隐覆盖多少个字符。

### 6. 彩虹 `rainbow`

让文字循环显示彩虹颜色。

```text
[rainbow freq=1.0 sat=0.8 val=0.8 speed=1.0]彩虹文字[/rainbow]
```

- `freq`：颜色重复范围。
- `sat`：饱和度。
- `val`：亮度。
- `speed`：变化速度；`0` 表示暂停，负数表示反向。

动态效果的移动强度不要设置得太大，否则文字可能与头像或对话框边缘重叠。

## 使用例子

### 加粗并变色

```gdscript
await Dialogue.entree(
	Dialogue.Character.NPC0,
	Dialogue.ExpressionState.SPEAKING,
	"这不是一次[b][color=#ff4040]普通事故[/color][/b]。",
)
```

### 局部颤抖

```gdscript
await Dialogue.entree(
	Dialogue.Character.NPC1,
	Dialogue.ExpressionState.SPEAKING,
	"它就在[shake rate=20 level=5]门后面[/shake]！",
)
```

### 多种效果组合

```gdscript
await Dialogue.entree(
	Dialogue.Character.NPC1,
	Dialogue.ExpressionState.SPEAKING,
	"千万不要打开[b][color=#ff3030][shake rate=25 level=5]那扇门[/shake][/color][/b]！",
)
```

### 带格式的旁白

```gdscript
await Dialogue.entree(
	Dialogue.Character.NARRATOR,
	Dialogue.ExpressionState.NORMAL,
	"[center][font_size=22][outline_size=1][outline_color=black]第十六层[/outline_color][/outline_size][/font_size][/center][br][color=#a0a0a0]这里没有任何出口。[/color]",
)
```
