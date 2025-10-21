# EOSG Android Export Helper

Standalone plugin that automatically configures your Android build template for Epic Online Services.

## What's Included

- `plugin.gd` - Main plugin registration
- `export_plugin.gd` - Export automation logic
- `env.gd` - Environment variable loader (autoload singleton)
- `eos_credentials.gd` - Credentials wrapper class (autoload singleton)
- `login.gd` - Simple example login script using EOSCredentials
- `.env.example` - Template for your credentials file

## Requirements

- Epic Online Services Godot plugin installed at `res://addons/epic-online-services-godot/`
- Android build template installed (Project -> Install Android Build Template)

## Quick Start Guide

### 1. Install the Plugin

Copy this plugin to `res://addons/eos-android-export/` and enable it in:

```
Project -> Project Settings -> Plugins -> Enable "EOS Android Export Helper"
```

### 2. Configure Credentials

Copy `.env.example` to your project root as `.env` and fill in your EOS credentials:

```env
# res://.env
PRODUCT_NAME=MyGameName
PRODUCT_VERSION=1.0.0
PRODUCT_ID=your_product_id
SANDBOX_ID=your_sandbox_id
DEPLOYMENT_ID=your_deployment_id
CLIENT_ID=your_client_id
CLIENT_SECRET=your_client_secret
```

Get your credentials from [Epic Games Developer Portal](https://dev.epicgames.com/portal)

### 3. Setup Login

Add a Control node to your main scene and attach the script directly from the plugin:

```
res://addons/eos-android-export/login.gd
```

This will:

- Initialize EOS with your credentials from `.env`
- Login using DevAuth Tool (for development)
- Switch to anonymous login by uncommenting `_anonymous_login()` in the script

### 4. Export for Android

Enable the Android build template:

```
Project -> Install Android Build Template
```

Then export normally:

```
Project -> Export -> Android
```

The plugin will automatically:
- ✅ Configure all Android build files for EOS (build.gradle, config.gradle, GodotApp.java)
- ✅ Include your `.env` file in the APK
- ✅ Inject the EOS login protocol scheme using your CLIENT_ID

No manual configuration needed!

### Client ID Priority

The plugin checks for the Client ID in this order:

1. Project Settings (`eos_android/client_id`)
2. EOSCredentials class (if you have it in your project)
3. `.env` file (`CLIENT_ID=...`)

## Advanced Usage

### Using EOSCredentials in Your Code

The plugin adds `EOSCredentials` as an autoload, so you can access credentials anywhere:

```gdscript
# Get individual credentials
var client_id = EOSCredentials.CLIENT_ID
var product_id = EOSCredentials.PRODUCT_ID

# Validate all credentials are set
if EOSCredentials.validate():
    print("All credentials configured!")

# Debug print (with secrets masked)
EOSCredentials.debug_print()
```

### Using Env Helper

The `Env` autoload lets you read any variable from `.env`:

```gdscript
# Get custom variables from .env
var my_custom_value = Env.get_var("MY_CUSTOM_VAR", "default")

# Check if variable exists
if Env.has_var("DEBUG_MODE"):
    print("Debug mode enabled")
```

### Login Methods

The included `login.gd` shows two login methods:

**DevAuth (Development)**

- Requires DevAuth Tool running on `localhost:4545`
- Get it from [Epic Games Developer Portal](https://dev.epicgames.com/docs/dev-portal/dev-auth-tool)
- Enabled by default in `login.gd`

**Anonymous (Production)**

- No credentials required from user
- Creates a device-specific ID
- Uncomment `_anonymous_login()` in `login.gd` to use

### Customizing Login

You can modify `login.gd` directly in the plugin, copy it to your project for more control, or create your own:

```gdscript
extends Control

func _ready():
    # All credentials automatically loaded from .env
    var init_opts = EOS.Platform.InitializeOptions.new()
    init_opts.product_name = EOSCredentials.PRODUCT_NAME
    init_opts.product_version = EOSCredentials.PRODUCT_VERSION

    # ... rest of your login code
```

## Important Notes

**Security**: Add `.env` to your `.gitignore` to keep credentials private!

**Android Export**: The plugin only modifies build files during export. Your existing files are safe.

## What It Does

- Adds EOS SDK dependencies to `build.gradle`
- Sets minimum SDK to 23 in `config.gradle`
- Injects EOS initialization code into `GodotApp.java`
- Configures OAuth login protocol scheme

## Settings

- `eos_android/client_id` - Your EOS Client ID from Epic Developer Portal
- `eos_android/enable_auto_config` - Enable/disable automatic configuration

## Note

This plugin looks for the EOS plugin at `res://addons/epic-online-services-godot/`. If the EOS plugin is not found, the export will fail with an error message.
Plugin can be found here https://github.com/3ddelano/epic-online-services-godot
