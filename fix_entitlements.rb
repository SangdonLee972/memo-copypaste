$LOAD_PATH.unshift(*Dir.glob(File.expand_path("~/.gem/ruby/2.6.0/gems/*/lib")))
require 'xcodeproj'

project_path = File.join(__dir__, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Add Runner.entitlements to Runner target
runner_target = project.targets.find { |t| t.name == 'Runner' }
runner_group = project.main_group.find_subpath('Runner', false)

# Add entitlements file reference to Runner group
runner_ent_ref = runner_group.new_file('Runner.entitlements')

# Set CODE_SIGN_ENTITLEMENTS for Runner
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
puts "Runner entitlements configured"

# Add MemoKeyboard.entitlements to MemoKeyboard target
keyboard_target = project.targets.find { |t| t.name == 'MemoKeyboard' }
keyboard_group = project.main_group.find_subpath('MemoKeyboard', false)

keyboard_ent_ref = keyboard_group.new_file('MemoKeyboard.entitlements')

keyboard_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'MemoKeyboard/MemoKeyboard.entitlements'
end
puts "MemoKeyboard entitlements configured"

project.save
puts "Done!"
