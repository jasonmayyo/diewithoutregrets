#!/usr/bin/env ruby
# Adds the diewithoutregretsTests unit-test target (host: diewithoutregrets).

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../diewithoutregrets.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == 'diewithoutregretsTests' }
  puts 'diewithoutregretsTests already exists — nothing to do.'
  exit 0
end

app_target = project.targets.find { |t| t.name == 'diewithoutregrets' }
raise 'app target not found' unless app_target

test_target = project.new_target(:unit_test_bundle, 'diewithoutregretsTests', :ios, '17.4')
group = project.main_group.new_group('diewithoutregretsTests', 'diewithoutregretsTests')
ref = group.new_reference('StudyGuardEngineTests.swift')
test_target.add_file_references([ref])
test_target.add_dependency(app_target)

test_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.jasonmayo.diewithoutregrets.Tests'
  bs['GENERATE_INFOPLIST_FILE'] = 'YES'
  bs['SWIFT_VERSION'] = '5.0'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = '17.4'
  bs['MARKETING_VERSION'] = '2.0.0'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = '5BFXSF2PS6'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/diewithoutregrets.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/diewithoutregrets'
  bs['BUNDLE_LOADER'] = '$(TEST_HOST)'
end

project.save
puts 'Created diewithoutregretsTests target.'
