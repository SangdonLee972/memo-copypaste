$LOAD_PATH.unshift(*Dir.glob(File.expand_path("~/.gem/ruby/2.6.0/gems/*/lib")))
require 'xcodeproj'

project_path = File.join(__dir__, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }

puts "Current build phases:"
runner_target.build_phases.each_with_index do |phase, i|
  puts "  #{i}: #{phase.display_name} (#{phase.class.name})"
end

# Find the Embed App Extensions phase
embed_phase = runner_target.build_phases.find { |p| p.display_name == 'Embed App Extensions' }
if embed_phase
  # Remove it from current position
  runner_target.build_phases.delete(embed_phase)
  # Add it as the very last phase
  runner_target.build_phases << embed_phase
  puts "\nMoved 'Embed App Extensions' to last position"
end

puts "\nNew build phases order:"
runner_target.build_phases.each_with_index do |phase, i|
  puts "  #{i}: #{phase.display_name} (#{phase.class.name})"
end

project.save
puts "\nDone!"
