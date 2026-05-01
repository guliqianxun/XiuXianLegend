class_name CustomerGenerator
extends RefCounted
## 程序化客人生成器。
## - 字典 × 组合规则 × tier 风味 → CustomerData
## - id 全 snake_case 英文（i18n key），display_name 中文
## - 生成的客人 ephemeral：不入 DataRegistry，由 CustomerRequest 直接持有引用

const SURNAMES_COMMON: Array[String] = [
	"赵", "钱", "孙", "李", "周", "吴", "郑", "王", "冯", "陈",
	"褚", "卫", "蒋", "沈", "韩", "杨", "朱", "秦", "尤", "许",
	"何", "吕", "施", "张", "孔", "曹", "严", "华", "金", "魏",
	"陶", "姜", "戚", "谢", "邹", "喻", "柏", "水", "窦", "章",
	"云", "苏", "潘", "葛", "奚", "范", "彭", "郎", "鲁", "韦",
]

const SURNAMES_RARE: Array[String] = [
	"东方", "上官", "欧阳", "端木", "南宫", "西门", "司马", "公孙",
	"诸葛", "令狐", "慕容", "皇甫", "尉迟", "赫连", "澹台", "公冶",
]

const GIVEN_ROOTS_COMMON: Array[String] = [
	"二", "三", "四", "五", "六", "七", "八", "九", "十",
	"大", "小", "老", "阿", "幺",
]

const GIVEN_ROOTS_RARE: Array[String] = [
	"云", "风", "雨", "雪", "霜", "霁", "旸", "曦", "岚", "旻",
	"舟", "川", "渚", "汀", "沼", "泠", "澈", "沄", "渊", "潇",
]

const TITLES_COMMON: Array[String] = [
	"跑腿", "捕快", "渔翁", "掌柜", "账房", "车夫", "酒保", "猎户",
	"邮差", "巡夜", "裁缝", "厨子", "船家", "脚夫",
]

const TITLES_RARE: Array[String] = [
	"道长", "郎中", "真人", "散修", "居士", "侠客", "判官", "术士",
	"云游", "僧人", "斋主", "堂主",
]

const TITLES_WEIRD: Array[String] = [
	"蒙面", "断指", "独眼", "跛足", "哑客", "白衣", "黑衣", "执灯",
	"提匣", "抱偶", "佝偻", "孤行",
]

const PATHS: Array[StringName] = [
	&"sword", &"curse", &"puppet", &"alchemy", &"eat", &"divination",
]

const FACTIONS: Array[StringName] = [
	&"wendao_zong", &"hanxing_zong", &"kurong_gu",
	&"wandan_men", &"wuqiu_yexiu", &"unknown",
]

# 酬金区间（按 tier 索引）
const PAYMENT_MIN: Array[int] = [80, 350, 600]
const PAYMENT_MAX: Array[int] = [200, 600, 1000]


## 主入口：按 tier 生成一个 CustomerData（不入 DataRegistry）
static func generate(rng: RandomNumberGenerator, tier: int, gen_seed: int) -> CustomerData:
	var t: int = clampi(tier, 0, 2)
	var c := CustomerData.new()
	c.id = StringName("gen:%d:%d" % [gen_seed, rng.randi() % 1000000])
	c.display_name = _make_name(rng, t)
	c.tier = t
	c.path_affinity = PATHS[rng.randi() % PATHS.size()]
	c.faction = FACTIONS[rng.randi() % FACTIONS.size()]
	c.base_payment = rng.randi_range(PAYMENT_MIN[t], PAYMENT_MAX[t])
	c.allowed_shichen = []  # 任意时辰
	c.faction_state_bonus = 0.0
	c.traits = _make_traits(rng, t)
	# 怪客 30% 伪装
	if t == 2 and rng.randf() < 0.30:
		c.disguise_name = _make_name(rng, 1)  # 伪装为 RARE 风格
		c.disguise_tier = 1
	else:
		c.disguise_name = ""
		c.disguise_tier = -1
	return c


static func _pick(rng: RandomNumberGenerator, pool: Array) -> String:
	return pool[rng.randi() % pool.size()]


static func _make_name(rng: RandomNumberGenerator, tier: int) -> String:
	match tier:
		0:  # REGULAR：姓 + 职衔
			return _pick(rng, SURNAMES_COMMON) + _pick(rng, TITLES_COMMON)
		1:  # RARE：罕姓 30% 或 常姓 + 罕字根（再可选 +职衔）
			var surname: String
			if rng.randf() < 0.30:
				surname = _pick(rng, SURNAMES_RARE)
			else:
				surname = _pick(rng, SURNAMES_COMMON)
			var name: String = surname + _pick(rng, GIVEN_ROOTS_RARE)
			if rng.randf() < 0.40:
				name += _pick(rng, TITLES_RARE)
			return name
		2:  # WEIRD：称号 + 客
			return _pick(rng, TITLES_WEIRD) + "客"
		_:
			return "陌客"


## 按 tier 抽 trait（从 ShopRules.TRAIT_LIBRARY），不重复
static func _make_traits(rng: RandomNumberGenerator, tier: int) -> Array[StringName]:
	var pool: Array[StringName] = []
	for k in ShopRules.TRAIT_LIBRARY:
		pool.append(k)
	var n: int = 0
	match tier:
		0:
			n = 0 if rng.randf() < 0.30 else 1
		1:
			n = 1 if rng.randf() < 0.70 else 2
		2:
			n = 2 if rng.randf() < 0.50 else 3
	# Fisher-Yates with rng（确定性）
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: StringName = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array[StringName] = []
	for i in mini(n, pool.size()):
		out.append(pool[i])
	return out
