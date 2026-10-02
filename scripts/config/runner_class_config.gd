@tool
## One runner class = one life. PlayerConfig.classes lists them in order of lives lost
## (entry 1 is used first); the number of entries is the number of lives.
class_name RunnerClassConfig
extends Resource

enum Ability {
	NONE,      ## No death ability
	BOMB,      ## Explodes on death, destroying defense units within range
	ENGINEER,  ## Leaves a patrolling platform on death
}

## Class name (shown in the HUD).
@export var display_name: String = "跑者"
## Body color.
@export var color: Color = Color("#4a7fe0")
## Maximum jump count (including the ground jump): 2 = double jump, 3 = triple jump.
@export_range(1, 10, 1) var max_jumps: int = 2
## Ability triggered on death.
@export var death_ability: Ability = Ability.NONE
## Ability description (shown in the HUD).
@export var description: String = ""
