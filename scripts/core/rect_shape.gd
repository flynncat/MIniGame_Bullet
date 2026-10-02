@tool
## Helper that manages a single rectangle collision shape through the shape-owner API,
## so level components need no hand-authored CollisionShape2D children.
class_name RectShape
extends RefCounted

## Creates or updates one rectangle shape owner on [param body]. Returns the owner id to reuse.
static func apply(body: CollisionObject2D, owner_id: int, rect: Rect2, one_way: bool = false) -> int:
	var id: int = owner_id
	if id < 0 or not body.get_shape_owners().has(id):
		id = body.create_shape_owner(body)
		body.shape_owner_add_shape(id, RectangleShape2D.new())
	var shape: RectangleShape2D = body.shape_owner_get_shape(id, 0) as RectangleShape2D
	shape.size = rect.size
	body.shape_owner_set_transform(id, Transform2D(0.0, rect.get_center()))
	body.shape_owner_set_one_way_collision(id, one_way)
	if one_way:
		body.shape_owner_set_one_way_collision_margin(id, 4.0)
	return id
