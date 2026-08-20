# Adds the StudyGuardReport DeviceActivity report-extension target.
# Clone of the add_shield_action_target.rb recipe (same gotchas):
#   - PRODUCT_NAME must be set explicitly or the build fails with
#     "Multiple commands produce .../.appex".
#   - The Embed Foundation Extensions phase must precede the Sentry dSYM
#     upload phase (commit 6c4e8ae).
# Run: ruby scripts/add_report_target.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../diewithoutregrets.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

NAME = 'StudyGuardReport'.freeze

if project.targets.any? { |t| t.name == NAME }
  puts "#{NAME} already exists — aborting to stay safe."
  exit 1
end

app_target = project.targets.find { |t| t.name == 'diewithoutregrets' }
raise 'app target not found' unless app_target

app_settings = app_target.build_configurations.first.build_settings

target = project.new_target(:app_extension, NAME, :ios, '17.4')

group = project.main_group.new_group(NAME, NAME)
file_refs = {}
['StudyGuardReportExtension.swift', 'TopOffendersReport.swift',
 'PrivacyInfo.xcprivacy', 'Info.plist', "#{NAME}.entitlements"].each do |fname|
  file_refs[fname] = group.new_reference(fname)
end

target.build_configurations.each do |config|
  bs = config.build_settings
  bs.delete('ASSETCATALOG_COMPILER_APPICON_NAME')
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = "com.jasonmayo.diewithoutregrets.#{NAME}"
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
  bs['INFOPLIST_FILE'] = "#{NAME}/Info.plist"
  bs['GENERATE_INFOPLIST_FILE'] = 'YES'
  bs['CODE_SIGN_ENTITLEMENTS'] = "#{NAME}/#{NAME}.entitlements"
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = '5BFXSF2PS6'
  bs['CURRENT_PROJECT_VERSION'] = app_settings['CURRENT_PROJECT_VERSION'] || '1'
  bs['MARKETING_VERSION'] = app_settings['MARKETING_VERSION'] || '2.0.0'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = '17.4'
  bs['SWIFT_VERSION'] = '5.0'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  bs['INFOPLIST_KEY_CFBundleDisplayName'] = NAME
  bs['INFOPLIST_KEY_NSHumanReadableCopyright'] = ''
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  bs['SKIP_INSTALL'] = 'YES'
end

target.add_file_references([
  file_refs['StudyGuardReportExtension.swift'],
  file_refs['TopOffendersReport.swift'],
])
target.resources_build_phase.add_file_reference(file_refs['PrivacyInfo.xcprivacy'])

app_target.add_dependency(target)

# ExtensionKit-style extension (EXAppExtensionAttributes Info.plist): must
# embed into Extensions/ via the ExtensionKit phase. Embedding into
# PlugIns/ via 'Embed Foundation Extensions' installs-fails with "Invalid
# placeholder attributes".
embed = app_target.copy_files_build_phases.find { |p| p.name == 'Embed ExtensionKit Extensions' }
raise 'Embed ExtensionKit Extensions phase not found' unless embed
bf = embed.add_file_reference(target.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

sentry = app_target.build_phases.find { |p| p.respond_to?(:name) && p.name.to_s.include?('Sentry') }
if sentry && app_target.build_phases.index(embed) > app_target.build_phases.index(sentry)
  raise 'phase order broken: embed must precede the Sentry dSYM upload'
end

project.save
puts 'Done. Targets now:'
project.targets.each { |t| puts "  #{t.name}" }
