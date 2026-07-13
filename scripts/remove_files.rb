#!/usr/bin/env ruby
# Remove file references (and their build-phase entries) from the project.
# Usage: ruby scripts/remove_files.rb <file-basename> ...

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../diewithoutregrets.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

ARGV.each do |basename|
  refs = project.files.select { |f| f.path && File.basename(f.path) == basename }
  if refs.empty?
    puts "not in project: #{basename}"
    next
  end
  refs.each do |ref|
    project.targets.each do |target|
      target.build_phases.each do |phase|
        next unless phase.respond_to?(:files)
        phase.files.select { |bf| bf.file_ref == ref }.each(&:remove_from_project)
      end
    end
    ref.remove_from_project
    puts "removed: #{basename}"
  end
end

project.save
