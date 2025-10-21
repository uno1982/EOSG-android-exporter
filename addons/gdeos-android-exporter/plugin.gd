@tool
extends EditorPlugin

var export_plugin: EditorExportPlugin

func _enter_tree():
	# Add autoload singletons with unique names to avoid class_name conflicts
	add_autoload_singleton("EnvLoader", "res://addons/eos-android-export/env.gd")
	add_autoload_singleton("EOSCreds", "res://addons/eos-android-export/eos_credentials.gd")
	
	# Register export plugin
	export_plugin = preload("res://addons/eos-android-export/export_plugin.gd").new()
	add_export_plugin(export_plugin)
	
	# Register project settings
	_register_settings()

func _exit_tree():
	# Remove autoload singletons
	remove_autoload_singleton("EnvLoader")
	remove_autoload_singleton("EOSCreds")
	
	# Remove export plugin
	if export_plugin:
		remove_export_plugin(export_plugin)
		export_plugin = null

func _register_settings():
	# Only register the enable_auto_config setting
	# Client ID now comes from .env file (not stored in project settings)
	if not ProjectSettings.has_setting("eos_android/enable_auto_config"):
		ProjectSettings.set_setting("eos_android/enable_auto_config", true)
		ProjectSettings.add_property_info({
			"name": "eos_android/enable_auto_config",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Automatically configure Android build files for EOS"
		})
		ProjectSettings.set_initial_value("eos_android/enable_auto_config", true)
	
	ProjectSettings.save()
