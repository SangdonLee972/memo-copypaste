$LOAD_PATH.unshift(*Dir.glob(File.expand_path("~/.gem/ruby/2.6.0/gems/*/lib")))
require 'xcodeproj'

project_path = File.join(__dir__, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Check if MemoKeyboard target already exists
if project.targets.any? { |t| t.name == 'MemoKeyboard' }
  puts "MemoKeyboard target already exists!"
  exit 0
end

# Get Runner target for reference
runner_target = project.targets.find { |t| t.name == 'Runner' }
bundle_id = 'com.copynote.memoCopypaste.MemoKeyboard'

# Create the app extension target
keyboard_target = project.new_target(:app_extension, 'MemoKeyboard', :ios, '13.0', nil, :swift)
keyboard_target.product_name = 'MemoKeyboard'

# Add MemoKeyboard group and files
keyboard_group = project.main_group.new_group('MemoKeyboard', 'MemoKeyboard')

swift_ref = keyboard_group.new_file('KeyboardViewController.swift')
info_ref = keyboard_group.new_file('Info.plist')

# Clear default source build phase files and add our swift file
keyboard_target.source_build_phase.files.each { |f| f.remove_from_project }
keyboard_target.source_build_phase.add_file_reference(swift_ref)

# Set build settings for all configurations
keyboard_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  config.build_settings['INFOPLIST_FILE'] = 'MemoKeyboard/Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''  # Will use automatic signing
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['SKIP_INSTALL'] = 'YES'

  if config.name == 'Debug'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
  end
end

# Add dependency: Runner depends on MemoKeyboard
runner_target.add_dependency(keyboard_target)

# Add "Embed App Extensions" copy phase to Runner
embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13'  # 13 = PlugIns folder for extensions

build_file = embed_phase.add_file_reference(keyboard_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Add Profile configuration if missing (Flutter projects have Debug, Release, Profile)
existing_config_names = keyboard_target.build_configurations.map(&:name)
unless existing_config_names.include?('Profile')
  profile_config = keyboard_target.add_build_configuration('Profile', :release)
  profile_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  profile_config.build_settings['INFOPLIST_FILE'] = 'MemoKeyboard/Info.plist'
  profile_config.build_settings['SWIFT_VERSION'] = '5.0'
  profile_config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  profile_config.build_settings['DEVELOPMENT_TEAM'] = ''
  profile_config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  profile_config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  profile_config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  profile_config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  profile_config.build_settings['MARKETING_VERSION'] = '1.0'
  profile_config.build_settings['SKIP_INSTALL'] = 'YES'
end

project.save
puts "MemoKeyboard target added successfully!"
