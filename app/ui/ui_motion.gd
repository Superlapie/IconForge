extends RefCounted
class_name UiMotion

static func tween_property(node: Node, property: NodePath, target: Variant, duration: float = 0.18) -> Tween:
	var tween: Tween = node.create_tween()
	tween.tween_property(node, property, target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween

static func tween_minimum_height(control: Control, target_height: float, duration: float = 0.18) -> Tween:
	return tween_property(control, "custom_minimum_size:y", target_height, duration)
