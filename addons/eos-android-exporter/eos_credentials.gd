extends Node
class_name EOSCredentials

## Centralized EOS credentials that can be accessed from anywhere
## Reads from .env file or provides defaults

# Product Information
static var PRODUCT_NAME: String:
	get: return Env.get_var("PRODUCT_NAME", "MyGame")

static var PRODUCT_VERSION: String:
	get: return Env.get_var("PRODUCT_VERSION", "1.0")

# EOS Configuration
static var PRODUCT_ID: String:
	get: return Env.get_var("PRODUCT_ID", "")

static var SANDBOX_ID: String:
	get: return Env.get_var("SANDBOX_ID", "")

static var DEPLOYMENT_ID: String:
	get: return Env.get_var("DEPLOYMENT_ID", "")

static var CLIENT_ID: String:
	get: return Env.get_var("CLIENT_ID", "")

static var CLIENT_SECRET: String:
	get: return Env.get_var("CLIENT_SECRET", "")

static var ENCRYPTION_KEY: String:
	get: return Env.get_var("ENCRYPTION_KEY", "")

## Helper to create HCredentials object with values from .env
static func to_hcredentials() -> HCredentials:
	var credentials = HCredentials.new()
	credentials.product_name = PRODUCT_NAME
	credentials.product_version = PRODUCT_VERSION
	credentials.product_id = PRODUCT_ID
	credentials.sandbox_id = SANDBOX_ID
	credentials.deployment_id = DEPLOYMENT_ID
	credentials.client_id = CLIENT_ID
	credentials.client_secret = CLIENT_SECRET
	if not ENCRYPTION_KEY.is_empty():
		credentials.encryption_key = ENCRYPTION_KEY
	return credentials

## Validate that all required credentials are set
static func validate() -> bool:
	var missing = []
	
	if PRODUCT_ID.is_empty():
		missing.append("PRODUCT_ID")
	if SANDBOX_ID.is_empty():
		missing.append("SANDBOX_ID")
	if DEPLOYMENT_ID.is_empty():
		missing.append("DEPLOYMENT_ID")
	if CLIENT_ID.is_empty():
		missing.append("CLIENT_ID")
	if CLIENT_SECRET.is_empty():
		missing.append("CLIENT_SECRET")
	
	if missing.size() > 0:
		push_error("EOSCredentials: Missing required environment variables: " + ", ".join(missing))
		return false
	
	return true

## Print all credentials (with secrets masked)
static func debug_print() -> void:
	print("=== EOS Credentials ===")
	print("PRODUCT_NAME: ", PRODUCT_NAME)
	print("PRODUCT_VERSION: ", PRODUCT_VERSION)
	print("PRODUCT_ID: ", PRODUCT_ID)
	print("SANDBOX_ID: ", SANDBOX_ID)
	print("DEPLOYMENT_ID: ", DEPLOYMENT_ID)
	print("CLIENT_ID: ", _mask_secret(CLIENT_ID))
	print("CLIENT_SECRET: ", _mask_secret(CLIENT_SECRET))
	print("ENCRYPTION_KEY: ", _mask_secret(ENCRYPTION_KEY))
	print("=======================")

static func _mask_secret(value: String) -> String:
	if value.is_empty():
		return "<not set>"
	if value.length() <= 8:
		return "***"
	return value.substr(0, 4) + "..." + value.substr(value.length() - 4, 4)
