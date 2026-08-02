# Removes retired meme-video-era files from the project and disk.
# Run: ruby scripts/remove_dead_design_files.rb
require "xcodeproj"

project_path = File.expand_path("../diewithoutregrets.xcodeproj", __dir__)
project = Xcodeproj::Project.open(project_path)

DEAD = %w[AnimationType.swift AnimationOptionRow.swift MemeVideoView.swift]

removed = []
project.files.select { |f| DEAD.include?(f.path.to_s.split("/").last) }.each do |ref|
  full = ref.real_path.to_s
  ref.remove_from_project
  File.delete(full) if File.exist?(full)
  removed << full
end

project.save
puts removed.empty? ? "nothing removed" : removed.join("\n")
