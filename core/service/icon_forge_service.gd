extends RefCounted
class_name IconForgeService

const _ApiService = preload("res://core/api/api_service.gd")

## Persistent transport wrapper around ApiService. Business logic stays in ApiService.

var workspace_root: String = ""
var api: RefCounted
var _request_in_flight: bool = false

func _init(root: String = "") -> void:
	workspace_root = root
	api = _ApiService.new(workspace_root)

func handle_request(request: Dictionary, safe_mode: bool = true) -> Dictionary:
	while _request_in_flight:
		await Engine.get_main_loop().process_frame
	_request_in_flight = true
	var response: Dictionary = await api.execute(request, safe_mode)
	_request_in_flight = false
	return response

func shutdown() -> Dictionary:
	return {"success": true, "status": "shutdown"}
