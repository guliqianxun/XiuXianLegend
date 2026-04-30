class_name NarrativeCard
extends Resource
## 手写叙事卡片。一段文本 + 触发条件。
## 程序化拼装日记段落走另一套（N5 实现）。

enum Trigger {
	CUSTOMER_FIRST = 0,           ## 客人首次到访
	WEIRD_CUSTOMER_FIRST = 1,     ## 怪客离奇行为
	BACKLASH = 2,                 ## 反噬异象
	QIAO_CHENG = 3,               ## 巧成 / 秘品出炉
	RESONANCE = 4,                ## 共鸣激活
	NOT_RETURNED = 5,             ## 不归还回流
	OLD_IRON_MUTTER = 6,          ## 老铁自言自语
	IDENTITY_FRAGMENT = 7,        ## 老铁身份暗线碎片
}

@export var id: StringName = &""

@export var trigger: Trigger = Trigger.OLD_IRON_MUTTER

## 主体文本（可含 \n 换行；不超过 500 字符——见 spec §12.2）
@export_multiline var body: String = ""

## 触发条件附加：当 trigger 是 CUSTOMER_FIRST 时，限定特定客人 id（空=任意）
@export var customer_id_filter: StringName = &""

## 触发条件附加：触发后是否一次性消耗（true=只触发一次，false=可反复触发）
@export var one_shot: bool = false
