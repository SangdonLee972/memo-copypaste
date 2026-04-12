$LOAD_PATH.unshift(*Dir.glob(File.expand_path("~/.gem/ruby/2.6.0/gems/*/lib")))
require 'xcodeproj'

project_path = File.join(__dir__, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }

# Remove Embed App Extensions from current position
embed_ext_phase = runner_target.build_phases.find { |p| p.display_name == 'Embed App Extensions' }
runner_target.build_phases.delete(embed_ext_phase)

# Find the index of "Embed Frameworks" and insert right after it (before Thin Binary)
embed_fw_idx = runner_target.build_phases.index { |p| p.display_name == 'Embed Frameworks' }
runner_target.build_phases.insert(embed_fw_idx + 1, embed_ext_phase)

puts "New build phases order:"
runner_target.build_phases.each_with_index do |phase, i|
  puts "  #{i}: #{phase.display_name}"
end

project.save
puts "Done!"
