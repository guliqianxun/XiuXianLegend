extends Node
## 数据注册表（Autoload 单例）。
## 启动时只扫描"索引"（路径列表），具体 Resource 按需 load + LRU 缓存。
## 任何静态配置（配方 / 客人 / 古谱 / 星宿 / 叙事 / 装备 / 词缀）都从这里取，禁止脚本里硬编码常量。

const LRU_CAP := 200
const INDEX_DIRS := {
	&"gear": "res://data/gear",
	&"affix": "res://data/affixes",
	&"recipe": "res://data/recipes",
	&"customer": "res://data/customers",
	&"gupu": "res://data/gupu",
	&"su": "res://data/sus",
	&"narrative": "res://data/narratives",
	&"faction": "res://data/factions",
	&"material": "res://data/materials",
}

# category -> { id: path }
var _index: Dictionary = {}

# (category, id) -> Resource
var _cache: Dictionary = {}
var _lru_keys: Array = []


func _ready() -> void:
	for cat: StringName in INDEX_DIRS:
		_index[cat] = _scan_dir(INDEX_DIRS[cat])


func _scan_dir(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		if not name.ends_with(".tres") and not name.ends_with(".res"):
			continue
		var id := name.get_basename()
		out[StringName(id)] = "%s/%s" % [dir_path, name]
	dir.list_dir_end()
	return out


func get_resource(category: StringName, id: StringName) -> Resource:
	var key := "%s/%s" % [category, id]
	if _cache.has(key):
		_touch_lru(key)
		return _cache[key]
	var paths: Dictionary = _index.get(category, {})
	if not paths.has(id):
		push_warning("data: missing %s/%s" % [category, id])
		return null
	var res := ResourceLoader.load(paths[id])
	_cache[key] = res
	_touch_lru(key)
	return res


func ids_of(category: StringName) -> Array:
	return (_index.get(category, {}) as Dictionary).keys()


func _touch_lru(key: String) -> void:
	_lru_keys.erase(key)
	_lru_keys.append(key)
	while _lru_keys.size() > LRU_CAP:
		var evict: String = _lru_keys.pop_front()
		_cache.erase(evict)
