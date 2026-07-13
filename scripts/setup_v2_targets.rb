#!/usr/bin/env ruby
# Study Guard v2 scaffolding: creates the StudyGuardMonitor + StudyGuardShield
# appex targets, a PlugIns embed phase, bumps deployment targets to 17.4, and
# aligns MARKETING_VERSION 2.0.0 across all targets. Idempotent-ish: bails if
# the targets already exist.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../diewithoutregrets.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == 'StudyGuardMonitor' }
  puts 'StudyGuardMonitor already exists — aborting to stay safe.'
  exit 1
end

app_target = project.targets.find { |t| t.name == 'diewithoutregrets' }
raise 'app target not found' unless app_target

MARKETING_VERSION = '2.0.0'
BUILD_NUMBER = '1'
DEPLOYMENT_TARGET = '17.4'

# --- 1. Project + existing-target build settings ---------------------------
project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
end

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
    config.build_settings['MARKETING_VERSION'] = MARKETING_VERSION
    config.build_settings['CURRENT_PROJECT_VERSION'] = BUILD_NUMBER
  end
end

# --- 2. Helper to build one extension target --------------------------------
def make_extension_target(project, app_target, name:, point_dir:, sources:, resources:)
  target = project.new_target(:app_extension, name, :ios, DEPLOYMENT_TARGET)

  # Group with folder reference paths relative to project root
  group = project.main_group.new_group(name, point_dir)
  file_refs = {}
  (sources + resources + ["Info.plist", "#{name}.entitlements"]).each do |fname|
    file_refs[fname] = group.new_reference(fname)
  end

  target.build_configurations.each do |config|
    bs = config.build_settings
    bs.delete('ASSETCATALOG_COMPILER_APPICON_NAME')
    bs['PRODUCT_BUNDLE_IDENTIFIER'] = "com.jasonmayo.diewithoutregrets.#{name}"
    bs['INFOPLIST_FILE'] = "#{name}/Info.plist"
    bs['GENERATE_INFOPLIST_FILE'] = 'YES'
    bs['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
    bs['CODE_SIGN_STYLE'] = 'Automatic'
    bs['DEVELOPMENT_TEAM'] = '5BFXSF2PS6'
    bs['CURRENT_PROJECT_VERSION'] = BUILD_NUMBER
    bs['MARKETING_VERSION'] = MARKETING_VERSION
    bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
    bs['SWIFT_VERSION'] = '5.0'
    bs['TARGETED_DEVICE_FAMILY'] = '1,2'
    bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    bs['INFOPLIST_KEY_CFBundleDisplayName'] = name
    bs['INFOPLIST_KEY_NSHumanReadableCopyright'] = ''
    bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    bs['SKIP_INSTALL'] = 'YES'
  end

  sources.each { |f| target.add_file_references([file_refs[f]]) }
  resources.each { |f| target.resources_build_phase.add_file_reference(file_refs[f]) }

  app_target.add_dependency(target)
  target
end

monitor = make_extension_target(project, app_target,
  name: 'StudyGuardMonitor',
  point_dir: 'StudyGuardMonitor',
  sources: ['StudyGuardMonitorExtension.swift'],
  resources: ['PrivacyInfo.xcprivacy'])

shield = make_extension_target(project, app_target,
  name: 'StudyGuardShield',
  point_dir: 'StudyGuardShield',
  sources: ['StudyGuardShieldExtension.swift'],
  resources: ['PrivacyInfo.xcprivacy', 'shield-icon.png'])

# --- 3. Embed Foundation Extensions phase (PlugIns, dstSubfolderSpec 13) ----
embed_phase = app_target.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_phase.dst_path = ''
[monitor, shield].each do |t|
  bf = embed_phase.add_file_reference(t.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# --- 4. SGContract.swift into all five targets ------------------------------
dwr_group = project.main_group['diewithoutregrets'] || project.main_group.find_subpath('diewithoutregrets')
shared_group = dwr_group.new_group('Shared', 'Shared')
sg_contract_ref = shared_group.new_reference('SGContract.swift')

project.targets.each do |t|
  next unless %w[diewithoutregrets RegretGuardIntent OpenGuardIntent StudyGuardMonitor StudyGuardShield].include?(t.name)
  t.add_file_references([sg_contract_ref])
end

project.save
puts 'Done. Targets now:'
project.targets.each { |t| puts "  #{t.name} (#{t.product_type})" }
