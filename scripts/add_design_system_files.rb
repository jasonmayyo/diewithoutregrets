# Adds new DesignSystem files to the app target.
# Run: ruby scripts/add_design_system_files.rb
require "xcodeproj"

project_path = File.expand_path("../diewithoutregrets.xcodeproj", __dir__)
project = Xcodeproj::Project.open(project_path)

app = project.targets.find { |t| t.name == "diewithoutregrets" }
abort("app target not found") unless app

group = project.main_group.find_subpath("diewithoutregrets/DesignSystem", false) ||
        project.main_group.find_subpath("DesignSystem", false)
abort("DesignSystem group not found") unless group

added = []
%w[SGButton.swift SGGallery.swift].each do |name|
  next if group.files.any? { |f| f.path == name }
  ref = group.new_reference(name)
  app.add_file_references([ref])
  added << name
end

project.save
puts added.empty? ? "nothing to add" : "added: #{added.join(', ')}"
