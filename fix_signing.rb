$LOAD_PATH.unshift(*Dir.glob(File.expand_path("~/.gem/ruby/2.6.0/gems/*/lib")))
require 'xcodeproj'

project_path = File.join(__dir__, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

team_id = 'K8Q58KBK87'

# Set development team for MemoKeyboard
keyboard_target = project.targets.find { |t| t.name == 'MemoKeyboard' }
if keyboard_target
  keyboard_target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = team_id
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  end
  puts "MemoKeyboard signing configured with team #{team_id}"
end

# Also ensure Runner has the team set
runner_target = project.targets.find { |t| t.name == 'Runner' }
if runner_target
  runner_target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = team_id
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  end
  puts "Runner signing configured with team #{team_id}"
end

project.save
puts "Done!"
