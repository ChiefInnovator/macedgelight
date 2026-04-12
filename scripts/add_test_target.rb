#!/usr/bin/env ruby
# Adds a unit-test target "MacEdgeLightTests" to MacEdgeLight.xcodeproj.
# Idempotent: running twice is safe — if the target already exists, bail out.

gem_root = "/opt/homebrew/Cellar/cocoapods/1.16.2_2/libexec/gems"
Dir.glob("#{gem_root}/*/lib").each { |p| $LOAD_PATH.unshift(p) }
require 'xcodeproj'

PROJECT_PATH = File.expand_path("../../MacEdgeLight.xcodeproj", __FILE__)
TESTS_DIR = File.expand_path("../../MacEdgeLightTests", __FILE__)
APP_TARGET_NAME = "MacEdgeLight"
TEST_TARGET_NAME = "MacEdgeLightTests"
BUNDLE_ID = "com.richardcrane.macedgelighttests"

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == TEST_TARGET_NAME }
  puts "Test target '#{TEST_TARGET_NAME}' already exists — skipping."
  exit 0
end

app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
raise "App target '#{APP_TARGET_NAME}' not found" unless app_target

deployment_target = app_target.build_configurations.first.build_settings["MACOSX_DEPLOYMENT_TARGET"] || "13.0"

# Create the test target via Xcodeproj's helper — this wires up sensible
# default build settings, build phases, and the test-host linkage.
test_target = project.new_target(
  :unit_test_bundle,
  TEST_TARGET_NAME,
  :osx,
  deployment_target,
  nil,
  :swift
)

# Test target build settings — hosted inside the app so @testable import works.
test_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = BUNDLE_ID
  config.build_settings["PRODUCT_MODULE_NAME"] = TEST_TARGET_NAME
  config.build_settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = deployment_target
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  config.build_settings["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "NO"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
  config.build_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/#{APP_TARGET_NAME}.app/Contents/MacOS/#{APP_TARGET_NAME}"
  config.build_settings["INFOPLIST_KEY_CFBundleDisplayName"] = TEST_TARGET_NAME
end

# The test bundle needs the app target as a dependency (so the app builds first).
test_target.add_dependency(app_target)

# Create a group for the test files and add them as sources
tests_group = project.main_group.find_subpath(TEST_TARGET_NAME, true)
tests_group.set_path(TEST_TARGET_NAME)
tests_group.set_source_tree("<group>")

Dir.glob("#{TESTS_DIR}/*.swift").sort.each do |swift_file|
  relative_path = File.basename(swift_file)
  file_ref = tests_group.new_reference(relative_path)
  file_ref.last_known_file_type = "sourcecode.swift"
  test_target.source_build_phase.add_file_reference(file_ref, true)
end

# Make sure the new test target appears in the default scheme so `xcodebuild
# test -scheme MacEdgeLight` picks it up.
scheme_path = Xcodeproj::XCScheme.user_data_dir(PROJECT_PATH)
shared_scheme_dir = File.join(PROJECT_PATH, "xcshareddata", "xcschemes")
FileUtils.mkdir_p(shared_scheme_dir)
scheme_file = File.join(shared_scheme_dir, "#{APP_TARGET_NAME}.xcscheme")

scheme = if File.exist?(scheme_file)
  Xcodeproj::XCScheme.new(scheme_file)
else
  s = Xcodeproj::XCScheme.new
  s.configure_with_targets(app_target, test_target)
  s
end
scheme.add_test_target(test_target)
scheme.save_as(PROJECT_PATH, APP_TARGET_NAME, true)

project.save
puts "Added target '#{TEST_TARGET_NAME}' with #{Dir.glob("#{TESTS_DIR}/*.swift").length} test files."
