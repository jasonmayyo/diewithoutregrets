#!/usr/bin/env ruby
# Adds the StudyGuardShieldAction appex target (ShieldActionDelegate,
# com.apple.ManagedSettingsUI.shield-action-service): build settings mirroring
# StudyGuardShield, SGContract.swift membership, and embedding via the existing
# 'Embed Foundation Extensions' phase (which must stay before the Sentry dSYM
# upload phase — the 6c4e8ae Xcode Cloud cycle fix). Bails if the target exists.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../diewithoutregrets.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

NAME = 'StudyGuardShieldAction'
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
['StudyGuardShieldActionExtension.swift', 'PrivacyInfo.xcprivacy',
 'Info.plist', "#{NAME}.entitlements"].each do |fname|
  file_refs[fname] = group.new_reference(fname)
end

target.build_configurations.each do |config|
  bs = config.build_settings
  bs.delete('ASSETCATALOG_COMPILER_APPICON_NAME')
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = "com.jasonmayo.diewithoutregrets.#{NAME}"
  # REQUIRED: the gem otherwise resolves PRODUCT_NAME to empty and the build
  # dies with "Multiple commands produce …/.appex".
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

target.add_file_references([file_refs['StudyGuardShieldActionExtension.swift']])
target.resources_build_phase.add_file_reference(file_refs['PrivacyInfo.xcprivacy'])

# SGContract: reuse the existing file reference so all targets share one ref.
sg_contract = project.files.find { |f| f.path == 'SGContract.swift' }
raise 'SGContract.swift file reference not found' unless sg_contract
target.add_file_references([sg_contract])

app_target.add_dependency(target)

embed = app_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
raise 'Embed Foundation Extensions phase not found' unless embed
bf = embed.add_file_reference(target.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

sentry = app_target.build_phases.find { |p| p.respond_to?(:name) && p.name.to_s.include?('Sentry') }
if sentry && app_target.build_phases.index(embed) > app_target.build_phases.index(sentry)
  raise 'phase order broken: embed must precede the Sentry dSYM upload'
end

project.save
puts 'Done. Targets now:'
project.targets.each { |t| puts "  #{t.name} (#{t.product_type})" }
