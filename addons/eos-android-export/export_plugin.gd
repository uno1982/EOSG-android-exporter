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
	_modify_android_manifest()
	
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
	# Try Godot 4.6 path first, then fall back to 4.5
	var file_path_46 = "res://android/build/src/main/java/com/godot/game/GodotApp.java"
	var file_path_45 = "res://android/build/src/com/godot/game/GodotApp.java"
	var file_path = ""
	
	if FileAccess.file_exists(file_path_46):
		file_path = file_path_46
	elif FileAccess.file_exists(file_path_45):
		file_path = file_path_45
	else:
		push_error("Failed to find GodotApp.java at either:")
		push_error("  " + file_path_46 + " (Godot 4.6+)")
		push_error("  " + file_path_45 + " (Godot 4.5)")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open GodotApp.java at " + file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Check if already configured
	if content.contains("EOSSDK.init") and content.contains("onNewIntent"):
		print("GodotApp.java already configured")
		return
	
	# Add EOS and Intent imports
	var import_pattern = "import org.godotengine.godot.GodotActivity;"
	var import_pos = content.find(import_pattern)
	if import_pos != -1:
		var import_insert_pos = content.find("\n", import_pos) + 1
		var imports = """import com.epicgames.mobile.eossdk.EOSSDK;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
"""
		content = content.insert(import_insert_pos, imports)
	
	# Add static block with loadLibrary if not present
	if not content.contains("System.loadLibrary(\"EOSSDK\")"):
		var class_pattern = "public class GodotApp extends GodotActivity {"
		var class_pos = content.find(class_pattern)
		if class_pos != -1:
			var static_insert_pos = content.find("\n", class_pos) + 1
			var load_library = """\tstatic {
\t\tSystem.loadLibrary("EOSSDK");
\t}

"""
			content = content.insert(static_insert_pos, load_library)
	
	# Add EOSSDK.init in onCreate if not present
	if not content.contains("EOSSDK.init"):
		var oncreate_pattern = "public void onCreate(Bundle savedInstanceState) {"
		var oncreate_pos = content.find(oncreate_pattern)
		if oncreate_pos != -1:
			var init_insert_pos = content.find("\n", oncreate_pos) + 1
			content = content.insert(init_insert_pos, "\t\tEOSSDK.init(getActivity());\n\n")
	
	# Add onNewIntent override to handle OAuth callback
	if not content.contains("onNewIntent"):
		# Find the last closing brace (end of class)
		var last_brace = content.rfind("}")
		if last_brace != -1:
			var on_new_intent = """
\t@Override
\tprotected void onNewIntent(Intent intent) {
\t\tsuper.onNewIntent(intent);
\t\tsetIntent(intent);
\t\t
\t\t// Handle EOS OAuth deep link
\t\tUri data = intent.getData();
\t\tif (data != null) {
\t\t\tString scheme = data.getScheme();
\t\t\tif (scheme != null && scheme.startsWith("eos.")) {
\t\t\t\tLog.d("GODOT_EOS", "Received OAuth callback: " + data.toString());
\t\t\t\t// EOS SDK will automatically handle the callback
\t\t\t}
\t\t}
\t}
"""
			content = content.insert(last_brace, on_new_intent)
	
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("GodotApp.java configured successfully")

func _modify_android_manifest() -> void:
	# Try Godot 4.6 path first, then fall back to 4.5
	var file_path_46 = "res://android/build/src/main/AndroidManifest.xml"
	var file_path_45 = "res://android/build/AndroidManifest.xml"
	var file_path = ""
	
	if FileAccess.file_exists(file_path_46):
		file_path = file_path_46
	elif FileAccess.file_exists(file_path_45):
		file_path = file_path_45
	else:
		push_error("Failed to find AndroidManifest.xml at either:")
		push_error("  " + file_path_46 + " (Godot 4.6+)")
		push_error("  " + file_path_45 + " (Godot 4.5)")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open AndroidManifest.xml at " + file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	var modified = false
	
	# Check if OAuth intent filter already configured
	if not content.contains("EOS OAuth redirect"):
		var client_id = _get_client_id()
		if client_id.is_empty():
			push_error("Cannot configure AndroidManifest without CLIENT_ID")
			return
		
		# Create the OAuth redirect scheme
		var scheme = "eos." + client_id.to_lower()
		
		# Find the end of the first intent-filter (the MAIN/LAUNCHER one)
		var intent_filter_end = content.find("</intent-filter>")
		if intent_filter_end == -1:
			push_error("Could not find intent-filter in AndroidManifest.xml")
			return
		
		# Insert the new intent-filter after the existing one
		var insert_pos = content.find("\n", intent_filter_end) + 1
		var oauth_intent_filter = """
            <!-- EOS OAuth redirect intent filter -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="%s" />
            </intent-filter>
""" % scheme
		
		content = content.insert(insert_pos, oauth_intent_filter)
		modified = true
		print("AndroidManifest.xml configured with OAuth scheme: " + scheme)
	
	# Ensure launchMode is singleTask for proper deep link handling
	if content.contains('android:launchMode="singleInstancePerTask"'):
		content = content.replace('android:launchMode="singleInstancePerTask"', 'android:launchMode="singleTask"')
		modified = true
		print("AndroidManifest.xml: Changed launchMode to singleTask for deep links")
	
	if modified:
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
	else:
		print("AndroidManifest.xml already configured")

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
