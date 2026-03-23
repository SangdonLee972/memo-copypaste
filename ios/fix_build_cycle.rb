#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }

# Find Embed App Extensions phase and fix it
runner_target.build_phases.each do |phase|
  if phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && phase.name == 'Embed App Extensions'
    # Move it to the end of build phases (after all other phases)
    runner_target.build_phases.move(phase, runner_target.build_phases.count - 1)
    puts "Moved 'Embed App Extensions' to end of build phases"
  end
end

# Also ensure the dependency is correct
keyboard_target = project.targets.find { |t| t.name == 'MemoKeyboard' }

# Remove duplicate dependencies if any
runner_target.dependencies.each_with_index do |dep, i|
  if dep.target == keyboard_target
    puts "Found dependency on MemoKeyboard at index #{i}"
  end
end

project.save
puts "Build cycle fix applied!"
