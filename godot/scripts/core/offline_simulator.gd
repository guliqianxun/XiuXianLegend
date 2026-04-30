extends Node
## 离线模拟器 Autoload。
## 启动时被 ShopScreen 调用，根据 last_settle_unix 推算「这段时间发生了什么」，
## 写成程序化日记条目（不修改 inventory，仅记录——避免无铺规情况下的 imbalance）。
##
## v1（N5a）：默认行为
##   - 每时辰 30% 概率开炉（写入 forge 日记）
##   - 每时辰 50% 概率来客（默认按规劝退，写入 customer_refuse 日记）
## v2（N5b 后）：用 ShopRule 替代默认行为，模拟器查规决定接/拒/造哪种
##
## 离线衰减：调 TimeLine.effective_offline_seconds；>24h 在头部加"老铁打盹"叙事。

const FORGE_PROB_PER_SHICHEN: float = 0.30
const CUSTOMER_PROB_PER_SHICHEN: float = 0.50

const SHICHEN_NAMES: Array[String] = [
	"子", "丑", "寅", "卯", "辰", "巳",
	"午", "未", "申", "酉", "戌", "亥",
]


## 主入口：根据「上次结算时戳」与「现在真实时戳」算离线时长，模拟事件，返回日记条目数组。
## 不修改 GameState；调用方负责把返回值塞 GameState.offline_diary_pending。
func simulate(last_settle_unix: int, real_now_unix: int) -> Array:
	var raw: int = real_now_unix - last_settle_unix
	if raw <= 0:
		return []
	var effective: int = TimeLine.effective_offline_seconds(raw)
	var diary: Array = []

	# 老铁打盹叙事卡（>24h 才出现）
	if raw > TimeLine.FULL_THRESHOLD_SEC:
		diary.append({
			"unix": last_settle_unix,
			"shichen": TimeLine.shichen_of_unix(last_settle_unix),
			"kind": &"sleep",
			"detail": _sleep_detail(raw),
		})

	# 按时辰节奏推进 effective 秒
	var rng := RandomNumberGenerator.new()
	rng.seed = last_settle_unix
	var n_shichen: int = effective / TimeLine.SECONDS_PER_SHICHEN
	var recipes: Array = _recipe_pool()
	var customers: Array = _customer_pool()

	for i in n_shichen:
		var cur_unix: int = last_settle_unix + (i + 1) * TimeLine.SECONDS_PER_SHICHEN
		var cur_shichen: int = TimeLine.shichen_of_unix(cur_unix)
		if rng.randf() < FORGE_PROB_PER_SHICHEN and not recipes.is_empty():
			var r: RecipeData = recipes[rng.randi() % recipes.size()]
			diary.append({
				"unix": cur_unix,
				"shichen": cur_shichen,
				"kind": &"forge",
				"detail": "%s时，炉火又起，出 %s 一件。" % [SHICHEN_NAMES[cur_shichen], r.display_name],
			})
		if rng.randf() < CUSTOMER_PROB_PER_SHICHEN and not customers.is_empty():
			var c: CustomerData = customers[rng.randi() % customers.size()]
			# 调铺规决策；伪装客人按 disguise 评估，可被攻破
			var req := CustomerRequest.new()
			req.customer_id = c.id
			req.arrived_unix = cur_unix
			var result: Dictionary = ShopRules.evaluate_offline(req, c)
			var perceived_name: String = c.display_name
			if not c.disguise_name.is_empty():
				perceived_name = c.disguise_name
			if result["action"] == &"refuse":
				diary.append({
					"unix": cur_unix,
					"shichen": cur_shichen,
					"kind": &"customer_refuse",
					"detail": "%s时，%s 来访，按规劝退。" % [SHICHEN_NAMES[cur_shichen], perceived_name],
				})
			else:
				diary.append({
					"unix": cur_unix,
					"shichen": cur_shichen,
					"kind": &"customer_lend",
					"detail": "%s时，借了一件给 %s。" % [SHICHEN_NAMES[cur_shichen], perceived_name],
				})
				if result["breached"]:
					# 攻破特殊条目：玩家以为放进去的是 disguise 客，结果是真名/真 tier
					diary.append({
						"unix": cur_unix,
						"shichen": cur_shichen,
						"kind": &"rule_breach",
						"detail": "——后来才看清，是 %s。铺规没拦住。" % c.display_name,
					})
					# 同时学到该客人的所有 trait（spec §7.3：攻破后永久解锁特征条款）
					# 注：simulate 故意不改 inventory，但 trait 学习是知识不是物资，
					# 不会造成数值膨胀，破坏隔离换交互闭环。
					if not c.traits.is_empty():
						GameState.learn_traits(c.traits)
	return diary


static func _sleep_detail(raw_seconds: int) -> String:
	if raw_seconds > TimeLine.DECAY_THRESHOLD_SEC:
		return "灶火早就凉了。老铁不知道睡了多久。"
	return "老铁趴在炉边睡过去了，错过了一些事。"


static func _recipe_pool() -> Array:
	var out: Array = []
	for rid in DataRegistry.ids_of(&"recipe"):
		var r := DataRegistry.get_resource(&"recipe", rid) as RecipeData
		if r != null:
			out.append(r)
	return out


static func _customer_pool() -> Array:
	var out: Array = []
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c != null:
			out.append(c)
	return out
