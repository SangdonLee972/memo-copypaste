$LOAD_PATH.unshift(*Dir.glob(File.expand_path("~/.gem/ruby/2.6.0/gems/*/lib")))
require 'xcodeproj'

project_path = File.join(__dir__, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

keyboard_target = project.targets.find { |t| t.name == 'MemoKeyboard' }
if keyboard_target
  keyboard_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_NAME'] = 'MemoKeyboard'
  end
  puts "PRODUCT_NAME set for MemoKeyboard"
end

project.save
puts "Done!"
