#!/usr/bin/env ruby
# Generic helper: add source files to the diewithoutregrets app target.
# Usage: ruby scripts/add_files.rb <path-relative-to-repo-root> ...
# Creates intermediate groups mirroring the folder structure under the
# `diewithoutregrets` group. Skips files that are already registered.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../diewithoutregrets.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == 'diewithoutregrets' }
raise 'app target not found' unless app_target

def find_or_make_group(parent, name)
  parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.name == name || c.path == name) } ||
    parent.new_group(name, name)
end

added = []
ARGV.each do |rel|
  parts = rel.split('/')
  raise "expected path under diewithoutregrets/: #{rel}" unless parts.first == 'diewithoutregrets'
  group = find_or_make_group(project.main_group, 'diewithoutregrets')
  parts[1..-2].each { |dir| group = find_or_make_group(group, dir) }
  fname = parts.last
  existing = group.children.find { |c| c.respond_to?(:path) && c.path == fname }
  if existing
    puts "skip (already present): #{rel}"
    next
  end
  ref = group.new_reference(fname)
  if fname.end_with?('.swift')
    app_target.add_file_references([ref])
  else
    app_target.resources_build_phase.add_file_reference(ref)
  end
  added << rel
end

project.save
puts "added: #{added.join(', ')}" unless added.empty?
