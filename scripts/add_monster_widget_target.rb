# Adds the MonsterWidgetExtension target (Live Activity widget) to the project
# and wires the app-side manager files into the app target.
# Run: ruby scripts/add_monster_widget_target.rb
require "xcodeproj"

project_path = File.expand_path("../diewithoutregrets.xcodeproj", __dir__)
project = Xcodeproj::Project.open(project_path)

app = project.targets.find { |t| t.name == "diewithoutregrets" }
abort("app target not found") unless app

if project.targets.any? { |t| t.name == "MonsterWidgetExtension" }
  abort("MonsterWidgetExtension already exists — nothing to do")
end

app_settings = app.build_configurations.first.build_settings
marketing = app_settings["MARKETING_VERSION"] || "1.0"
current = app_settings["CURRENT_PROJECT_VERSION"] || "1"

# --- Widget extension target ---------------------------------------------
widget = project.new_target(:app_extension, "MonsterWidgetExtension", :ios, "17.4")

widget.build_configurations.each do |config|
  config.build_settings.merge!(
    "CODE_SIGN_STYLE" => "Automatic",
    "DEVELOPMENT_TEAM" => "5BFXSF2PS6",
    "INFOPLIST_FILE" => "MonsterWidget/Info.plist",
    "INFOPLIST_KEY_CFBundleDisplayName" => "MonsterWidget",
    "INFOPLIST_KEY_NSHumanReadableCopyright" => "",
    "IPHONEOS_DEPLOYMENT_TARGET" => "17.4",
    "LD_RUNPATH_SEARCH_PATHS" => "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
    "MARKETING_VERSION" => marketing,
    "CURRENT_PROJECT_VERSION" => current,
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.jasonmayo.diewithoutregrets.MonsterWidget",
    "PRODUCT_NAME" => "$(TARGET_NAME)",
    "SKIP_INSTALL" => "YES",
    "SWIFT_EMIT_LOC_STRINGS" => "YES",
    "SWIFT_VERSION" => "5.0",
    "TARGETED_DEVICE_FAMILY" => "1,2"
  )
end

# --- Widget group + files -------------------------------------------------
group = project.main_group.new_group("MonsterWidget", "MonsterWidget")
bundle_ref = group.new_reference("MonsterWidgetBundle.swift")
activity_ref = group.new_reference("MonsterLiveActivity.swift")
attrs_ref = group.new_reference("MonsterLiveActivityAttributes.swift")
assets_ref = group.new_reference("Assets.xcassets")
group.new_reference("Info.plist")

widget.add_file_references([bundle_ref, activity_ref, attrs_ref])
widget.resources_build_phase.add_file_reference(assets_ref)

# --- Embed in the app -----------------------------------------------------
app.add_dependency(widget)
embed_phase = app.copy_files_build_phases.find { |p| p.name == "Embed Foundation Extensions" }
abort("embed phase not found") unless embed_phase
build_file = embed_phase.add_file_reference(widget.product_reference)
build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

# --- App-side files -------------------------------------------------------
app_group = project.main_group.find_subpath("diewithoutregrets", false)
abort("app group not found") unless app_group
manager_ref = app_group.new_reference("MonsterActivityManager.swift")
app_attrs_ref = app_group.new_reference("MonsterLiveActivityAttributes.swift")
app.add_file_references([manager_ref, app_attrs_ref])

project.save
puts "done"
