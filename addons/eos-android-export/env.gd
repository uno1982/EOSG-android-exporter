extends Node
class_name Env

## Simple environment variable loader for .env files
## Reads from res://.env and provides access to variables

static var _variables: Dictionary = {}
static var _loaded: bool = false

static func _load_env() -> void:
	if _loaded:
		return
	
	_loaded = true
	
	var env_path = "res://.env"
	if not FileAccess.file_exists(env_path):
		push_warning("Env: .env file not found at " + env_path)
		return
	
	var file = FileAccess.open(env_path, FileAccess.READ)
	if not file:
		push_error("Env: Failed to open .env file")
		return
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue
		
		var key = ""
		var value = ""
		
		# Parse GDScript format: key: String = "value"
		if ":" in line and "=" in line:
			var colon_pos = line.find(":")
			var eq_pos = line.find("=")
			if colon_pos < eq_pos:
				key = line.substr(0, colon_pos).strip_edges().to_upper()
				value = line.substr(eq_pos + 1).strip_edges()
		# Parse standard format: KEY=value
		elif "=" in line:
			var parts = line.split("=", true, 1)
			if parts.size() == 2:
				key = parts[0].strip_edges().to_upper()
				value = parts[1].strip_edges()
		
		if not key.is_empty():
			# Remove quotes if present
			if value.begins_with('"') and value.ends_with('"'):
				value = value.substr(1, value.length() - 2)
			elif value.begins_with("'") and value.ends_with("'"):
				value = value.substr(1, value.length() - 2)
			
			_variables[key] = value
	
	file.close()
	print("Env: Loaded ", _variables.size(), " variables from .env")

static func get_var(key: String, default_value: String = "") -> String:
	if not _loaded:
		_load_env()
	
	return _variables.get(key, default_value)

static func has_var(key: String) -> bool:
	if not _loaded:
		_load_env()
	
	return _variables.has(key)

static func get_all() -> Dictionary:
	if not _loaded:
		_load_env()
	
	return _variables.duplicate()
