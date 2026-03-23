#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Check if MemoKeyboard target already exists
if project.targets.any? { |t| t.name == 'MemoKeyboard' }
  puts "MemoKeyboard target already exists!"
  exit 0
end

# Get Runner target for reference
runner_target = project.targets.find { |t| t.name == 'Runner' }

# Create the keyboard extension target
keyboard_target = project.new_target(:app_extension, 'MemoKeyboard', :ios, '13.0', nil, :swift)

# Add source files
keyboard_group = project.main_group.new_group('MemoKeyboard', 'MemoKeyboard')

swift_ref = keyboard_group.new_file('KeyboardViewController.swift')
plist_ref = keyboard_group.new_file('Info.plist')

# Add swift file to sources build phase
keyboard_target.source_build_phase.add_file_reference(swift_ref)

# Set build settings
keyboard_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.copynote.memoCopypaste.MemoKeyboard'
  config.build_settings['INFOPLIST_FILE'] = 'MemoKeyboard/Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  # libsqlite3 linking
  config.build_settings['OTHER_LDFLAGS'] = ['-lsqlite3']
end

# Add MemoKeyboard as dependency of Runner and embed it
runner_target.add_dependency(keyboard_target)

# Add Embed App Extensions build phase
embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13' # plugins/app extensions
embed_phase.build_action_mask = '2147483647'

keyboard_product = keyboard_target.product_reference
build_file = embed_phase.add_file_reference(keyboard_product)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save

puts "MemoKeyboard target added successfully!"
puts "Bundle ID: com.copynote.memoCopypaste.MemoKeyboard"
