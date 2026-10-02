@tool
## Player-2 (defender) configuration: economy + per-item stats.
## Main file: res://config/defense_config.tres (item stats live in res://config/defense/*.tres).
class_name DefenseConfig
extends Resource

@export_group("经济")
## Defender funds at the start of each run.
@export_range(0, 100000, 10, "or_greater") var start_budget: int = 400
## Passive income per second.
@export_range(0.0, 1000.0, 1.0, "suffix:/s") var income_per_sec: float = 20.0
## Funds the defender gains each time the runner picks up a coin.
@export_range(0, 10000, 10, "or_greater") var coin_bonus: int = 100

@export_group("道具")
## Gun turret stats.
@export var turret: TurretStats
## Rocket launcher stats.
@export var rocket: TurretStats
## Caltrop stats.
@export var caltrop: CaltropStats

func turret_stats(kind: Turret.Kind) -> TurretStats:
	var s: TurretStats = rocket if kind == Turret.Kind.ROCKET else turret
	return s if s else TurretStats.new()

func caltrop_stats() -> CaltropStats:
	return caltrop if caltrop else CaltropStats.new()

func price(item: DefenseCatalog.Item) -> int:
	match item:
		DefenseCatalog.Item.TURRET: return turret_stats(Turret.Kind.GUN).price
		DefenseCatalog.Item.ROCKET: return turret_stats(Turret.Kind.ROCKET).price
		DefenseCatalog.Item.CALTROP: return caltrop_stats().price
	return 0

func display_name(item: DefenseCatalog.Item) -> String:
	match item:
		DefenseCatalog.Item.TURRET: return turret_stats(Turret.Kind.GUN).display_name
		DefenseCatalog.Item.ROCKET: return turret_stats(Turret.Kind.ROCKET).display_name
		DefenseCatalog.Item.CALTROP: return caltrop_stats().display_name
	return ""

func description(item: DefenseCatalog.Item) -> String:
	match item:
		DefenseCatalog.Item.TURRET: return turret_stats(Turret.Kind.GUN).description
		DefenseCatalog.Item.ROCKET: return turret_stats(Turret.Kind.ROCKET).description
		DefenseCatalog.Item.CALTROP: return caltrop_stats().description
	return ""

func arm_time(item: DefenseCatalog.Item) -> float:
	match item:
		DefenseCatalog.Item.TURRET: return turret_stats(Turret.Kind.GUN).arm_time
		DefenseCatalog.Item.ROCKET: return turret_stats(Turret.Kind.ROCKET).arm_time
		DefenseCatalog.Item.CALTROP: return caltrop_stats().arm_time
	return 0.0

## Price per placement after the item has been upgraded.
func upgraded_price(item: DefenseCatalog.Item) -> int:
	match item:
		DefenseCatalog.Item.TURRET: return turret_stats(Turret.Kind.GUN).upgraded_price
		DefenseCatalog.Item.ROCKET: return turret_stats(Turret.Kind.ROCKET).upgraded_price
		DefenseCatalog.Item.CALTROP: return caltrop_stats().upgraded_price
	return 0

## One-time cost of the shop "升级" button.
func upgrade_cost(item: DefenseCatalog.Item) -> int:
	match item:
		DefenseCatalog.Item.TURRET: return turret_stats(Turret.Kind.GUN).upgrade_cost
		DefenseCatalog.Item.ROCKET: return turret_stats(Turret.Kind.ROCKET).upgrade_cost
		DefenseCatalog.Item.CALTROP: return caltrop_stats().upgrade_cost
	return 0

## Upgrade effect text for the shop card.
func upgrade_summary(item: DefenseCatalog.Item) -> String:
	match item:
		DefenseCatalog.Item.TURRET: return turret_stats(Turret.Kind.GUN).upgrade_summary()
		DefenseCatalog.Item.ROCKET: return turret_stats(Turret.Kind.ROCKET).upgrade_summary()
		DefenseCatalog.Item.CALTROP: return caltrop_stats().upgrade_summary()
	return ""

## Largest arming time across items, for UI hints.
func max_arm_time() -> float:
	return maxf(maxf(arm_time(DefenseCatalog.Item.TURRET), arm_time(DefenseCatalog.Item.ROCKET)), arm_time(DefenseCatalog.Item.CALTROP))
