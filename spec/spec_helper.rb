# frozen_string_literal: true

require "rspec"

require "modspec"
require "jekyll"

# Use a simple test page instead of Jekyll::PageWithoutAFile to avoid
# Jekyll internals (in_theme_dir, etc.) in spec isolation.
Jekyll::PageWithoutAFile = Struct.new(:site, :base, :dir, :name, :data, :content) do
  def initialize(site, base, dir, name)
    self.site = site
    self.base = base
    self.dir = dir
    self.name = name
    self.data = {}
    self.content = ""
  end

  def path
    File.join(base, dir, name)
  end
end

# Load the plugin classes (skip standards_generator.rb which registers Jekyll hooks)
Dir[File.join(__dir__, "../source/_plugins/standards/*.rb")].sort.each { |f| require f }

FIXTURES_DIR = File.join(__dir__, "fixtures")
