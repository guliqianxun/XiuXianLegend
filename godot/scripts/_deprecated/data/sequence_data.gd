class_name SequenceData
extends Resource
## 道途定义。一条道途 10 阶（rank 9..0）。

@export var id: StringName                            ## sword / curse / puppet / elixir / eating / divination
@export var display_name: String
@export_multiline var lore: String

## rank -> SequenceRank（从 9 到 0），用 Array 索引：index 0 = rank 9
@export var ranks: Array[SequenceRank] = []


class SequenceRank extends Resource:
	@export var rank_label: String                    ## "序列 9 · 学徒"
	@export_multiline var description: String
	@export var unlock_cards: Array[StringName] = []  ## 升到该 rank 解锁的卡 id
	@export var stat_bonus: Dictionary = {}           ## { "attack": 5, "sanity_cap": 10 }
	@export var ritual_insight_cost: int = 0          ## 扮演仪式所需见闻
	@export var ritual_anomaly_id: StringName = &""   ## 仪式所需异常物
	@export_range(0.0, 1.0) var ritual_fail_chance: float = 0.1
