## Mutable per-run data shared (read-only) with the HUD. Owned by Game.
## Lives and runner classes come from PlayerConfig.
class_name RunState
extends RefCounted

var config: PlayerConfig = PlayerConfig.new()
var score: int = 0
## Coins collected during the whole run (never decreases when spending).
var coin_count: int = 0
## Coins collected in the current level (used for the per-level leaderboard).
var level_coins: int = 0
## Number of coins placed in the current level.
var coin_total: int = 0
## Spendable coins (shield / screen clear). Carried across levels within a run.
## This is the number ranked on the leaderboards ("remaining coins").
var wallet: int = 0
## Coins spent on abilities in the current level / in the whole run.
var level_spent: int = 0
var run_spent: int = 0
var lives: int = 3
var level_time: float = 0.0
var total_time: float = 0.0
var level_index: int = 0
var level_name: String = ""

func max_lives() -> int:
	return config.max_lives()

func reset_run() -> void:
	score = 0
	coin_count = 0
	wallet = 0
	run_spent = 0
	lives = max_lives()
	total_time = 0.0

## Spends [param amount] coins from the wallet. Returns false (and spends nothing) if short.
func spend(amount: int) -> bool:
	if wallet < amount:
		return false
	wallet -= amount
	level_spent += amount
	run_spent += amount
	return true

## Class for the current life (first entry while at full lives).
func current_class() -> RunnerClassConfig:
	return config.class_for_lives(lives)

## Class that was active before the most recent life was lost (call after lives--).
func class_just_lost() -> RunnerClassConfig:
	return config.class_for_lives(lives + 1)

static func format_time(t: float) -> String:
	var secs: int = int(t)
	return "%d:%02d" % [secs / 60, secs % 60]
