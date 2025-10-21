@tool
extends EditorExportPlugin

const EOS_PLUGIN_PATH = "res://addons/epic-online-services-godot"

func _get_name() -> String:
	return "EOS Android Export Helper"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	if platform is EditorExportPlatformAndroid:
		return true
	return false

func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	# Force include .env file in Android exports
	if path == "res://.env" and features.has("android"):
		# Read the .env file and add it to the export
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var content = file.get_buffer(file.get_length())
				file.close()
				# Add the file to the exported PCK
				add_file(path, content, false)
				print("EOS Android Export: Including .env file in export")

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	if not features.has("android"):
		return
	
	# Manually add .env file to export
	var env_path = "res://.env"
	if FileAccess.file_exists(env_path):
		var file = FileAccess.open(env_path, FileAccess.READ)
		if file:
			var content = file.get_buffer(file.get_length())
			file.close()
			add_file(env_path, content, false)
			print("EOS Android Export: Including .env file in export")
	else:
		push_warning("EOS Android Export: .env file not found! EOS credentials will not be available.")
		push_warning("Create res://.env with your EOS credentials for the app to work.")
	
	if not ProjectSettings.get_setting("eos_android/enable_auto_config", true):
		print("EOS Android Export: Auto-configuration disabled")
		return
	
	# Check if EOS plugin exists
	if not DirAccess.dir_exists_absolute(EOS_PLUGIN_PATH):
		push_error("EOS Android Export: Epic Online Services plugin not found at " + EOS_PLUGIN_PATH)
		push_error("Please install the Epic Online Services Godot plugin first")
		return
	
	# Check if Android build template exists
	if not DirAccess.dir_exists_absolute("res://android/build"):
		push_error("EOS Android Export: Android build template not found")
		push_error("Please install Android build template: Project -> Install Android Build Template")
		return
	
	print("EOS Android Export: Configuring Android build for EOS...")
	
	_modify_build_gradle()
	_modify_config_gradle()
	_modify_godot_app_java()
	
	print("EOS Android Export: Configuration complete")

func _modify_build_gradle() -> void:
	var file_path = "res://android/build/build.gradle"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open build.gradle")
		return
	
	var content = file.get_as_text()
	file.close()
	
	var modified = false
	
	# Check if dependencies are already configured
	if not content.contains("// EOS SDK dependencies"):
		# Find dependencies section and add EOS dependencies
		var deps_pos = content.find("dependencies {")
		if deps_pos == -1:
			push_error("Could not find dependencies section in build.gradle")
			return
		
		var insert_pos = content.find("\n", deps_pos) + 1
		var eos_deps = """
    // EOS SDK dependencies
    implementation 'androidx.appcompat:appcompat:1.5.1'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'androidx.security:security-crypto:1.0.0'
    implementation 'androidx.browser:browser:1.4.0'
    implementation 'androidx.webkit:webkit:1.7.0'
    implementation files('../../addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar')

"""
		content = content.insert(insert_pos, eos_deps)
		modified = true
	
	# Check if protocol scheme is already configured
	if not content.contains("eos_login_protocol_scheme"):
		# Add protocol scheme to defaultConfig
		var config_pos = content.find("missingDimensionStrategy 'products', 'template'")
		if config_pos != -1:
			var client_id = _get_client_id()
			if not client_id.is_empty():
				var scheme_insert_pos = content.find("\n", config_pos) + 1
				var scheme_config = """
        // EOS login protocol scheme
        String ClientId = "%s"
        resValue("string", "eos_login_protocol_scheme", "eos." + ClientId.toLowerCase())

""" % client_id
				content = content.insert(scheme_insert_pos, scheme_config)
				modified = true
			else:
				push_warning("EOS Client ID not found in .env file")
	
	if modified:
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			print("build.gradle configured successfully")
	else:
		print("build.gradle already configured")

func _modify_config_gradle() -> void:
	var file_path = "res://android/build/config.gradle"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open config.gradle")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Check and update minSdk to 23
	var min_sdk_regex = RegEx.new()
	min_sdk_regex.compile(r"minSdk\s*:\s*(\d+)")
	var result = min_sdk_regex.search(content)
	
	if result:
		var current_min_sdk = result.get_string(1).to_int()
		if current_min_sdk >= 23:
			print("config.gradle minSdk already >= 23")
			return
		
		content = min_sdk_regex.sub(content, "minSdk             : 23")
		
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			print("config.gradle minSdk updated to 23")

func _modify_godot_app_java() -> void:
	var file_path = "res://android/build/src/com/godot/game/GodotApp.java"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open GodotApp.java")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Check if already configured
	if content.contains("EOSSDK.init"):
		print("GodotApp.java already configured")
		return
	
	# Add EOS import
	var import_pattern = "import org.godotengine.godot.GodotActivity;"
	var import_pos = content.find(import_pattern)
	if import_pos != -1:
		var import_insert_pos = content.find("\n", import_pos) + 1
		content = content.insert(import_insert_pos, "import com.epicgames.mobile.eossdk.EOSSDK;\n")
	
	# Add static block with loadLibrary
	var class_pattern = "public class GodotApp extends GodotActivity {"
	var class_pos = content.find(class_pattern)
	if class_pos != -1:
		var static_insert_pos = content.find("\n", class_pos) + 1
		var load_library = """\tstatic {
\t\tSystem.loadLibrary("EOSSDK");
\t}

"""
		content = content.insert(static_insert_pos, load_library)
	
	# Add EOSSDK.init in onCreate
	var oncreate_pattern = "public void onCreate(Bundle savedInstanceState) {"
	var oncreate_pos = content.find(oncreate_pattern)
	if oncreate_pos != -1:
		var init_insert_pos = content.find("\n", oncreate_pos) + 1
		content = content.insert(init_insert_pos, "\t\tEOSSDK.init(getActivity());\n\n")
	
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			print("GodotApp.java configured successfully")

func _get_client_id() -> String:
	# Load client ID from .env file
	# Supports both formats:
	#   CLIENT_ID=value
	#   client_id: String = "value"
	if FileAccess.file_exists("res://.env"):
		var file = FileAccess.open("res://.env", FileAccess.READ)
		if file:
			while not file.eof_reached():
				var line = file.get_line().strip_edges()
				
				# Skip empty lines and comments
				if line.is_empty() or line.begins_with("#"):
					continue
				
				# Check if this line contains client_id (case insensitive)
				var lower_line = line.to_lower()
				if lower_line.begins_with("client_id"):
					var client_id = ""
					
					# Parse GDScript format: client_id: String = "value"
					if ":" in line:
						var parts = line.split("=", false, 1)
						if parts.size() == 2:
							client_id = parts[1].strip_edges()
					# Parse standard format: CLIENT_ID=value
					elif "=" in line:
						var eq_pos = line.find("=")
						client_id = line.substr(eq_pos + 1).strip_edges()
					
					# Remove quotes if present
					if client_id.begins_with('"') and client_id.ends_with('"'):
						client_id = client_id.substr(1, client_id.length() - 2)
					elif client_id.begins_with("'") and client_id.ends_with("'"):
						client_id = client_id.substr(1, client_id.length() - 2)
					
					if not client_id.is_empty():
						file.close()
						return client_id
			file.close()
	
	push_warning("EOS Client ID not found in .env file. Please create res://.env with CLIENT_ID=your_id")
	return ""
