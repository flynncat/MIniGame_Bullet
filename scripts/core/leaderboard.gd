## Local coin leaderboard, persisted with ConfigFile (IndexedDB on the web build).
## One board per level (keyed by the level scene path) plus one for full-game runs.
## Ranked value = coins REMAINING at settlement (collected minus spent on abilities);
## more coins first, ties broken by shorter time.
class_name Leaderboard
extends RefCounted

## Board id used for complete runs (all levels cleared).
const RUN_BOARD: String = "__full_run__"
## Entries kept per board.
const MAX_ENTRIES: int = 20
## v2: ranks remaining coins (v1 "boards" ranked collected coins and is ignored).
const SECTION: String = "remaining_v2"

## One recorded result.
class Entry:
	var coins: int = 0
	var time: float = 0.0
	## Local date/time "MM-DD HH:MM".
	var stamp: String = ""

	func to_dict() -> Dictionary:
		return {"coins": coins, "time": time, "stamp": stamp}

	static func from_dict(d: Dictionary) -> Entry:
		var e := Entry.new()
		e.coins = int(d.get("coins", 0))
		e.time = float(d.get("time", 0.0))
		e.stamp = String(d.get("stamp", ""))
		return e

	## True if this entry ranks above [param other].
	func beats(other: Entry) -> bool:
		if coins != other.coins:
			return coins > other.coins
		return time < other.time

var path: String

func _init(p_path: String = "user://leaderboard.cfg") -> void:
	path = p_path

## Records a result and returns its 1-based rank on [param board] (rank is computed
## before trimming, so a result below the kept entries still reports its position).
func submit(board: String, coins: int, time: float) -> int:
	var entries: Array[Entry] = top(board, MAX_ENTRIES)
	var e := Entry.new()
	e.coins = coins
	e.time = snappedf(time, 0.01)
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	e.stamp = "%02d-%02d %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]
	var rank: int = entries.size()
	for i: int in entries.size():
		if e.beats(entries[i]):
			rank = i
			break
	entries.insert(rank, e)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	_save(board, entries)
	return rank + 1

## Best [param n] entries of [param board], best first.
func top(board: String, n: int) -> Array[Entry]:
	var out: Array[Entry] = []
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return out
	var raw: Variant = cfg.get_value(SECTION, board, [])
	if raw is Array:
		for d: Variant in raw:
			if d is Dictionary and out.size() < n:
				out.append(Entry.from_dict(d))
	return out

func _save(board: String, entries: Array[Entry]) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	var raw: Array[Dictionary] = []
	for e: Entry in entries:
		raw.append(e.to_dict())
	cfg.set_value(SECTION, board, raw)
	var err: Error = cfg.save(path)
	if err != OK:
		push_warning("Leaderboard: could not save (%s)" % error_string(err))

## BBCode table for the overlays; [param highlight] is the 1-based rank to mark (0 = none).
func format_board(board: String, n: int, highlight: int) -> String:
	var entries: Array[Entry] = top(board, n)
	if entries.is_empty():
		return "暂无记录"
	var lines := PackedStringArray()
	for i: int in entries.size():
		var e: Entry = entries[i]
		var line: String = "第 %d 名　剩余 %d 金币　%.1fs　%s" % [i + 1, e.coins, e.time, e.stamp]
		lines.append("[color=#6cf0a0]▶ %s ◀[/color]" % line if i + 1 == highlight else line)
	return "\n".join(lines)
