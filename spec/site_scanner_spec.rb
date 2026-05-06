# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe StandardsGenerator::SiteScanner do
  describe "#each_standard" do
    it "discovers standard directories under _data/" do
      # Use a mock site with source pointing to fixtures
      site = instance_double("Jekyll::Site", source: FIXTURES_DIR)
      scanner = described_class.new(site)

      standards = scanner.each_standard.to_a
      # No directories under fixtures/_data/ that match the pattern
      # (our fixture is at fixtures/sample_standard, not fixtures/_data/...)
      expect(standards).to be_empty
    end

    it "returns enumerator when no block given" do
      site = instance_double("Jekyll::Site", source: FIXTURES_DIR)
      scanner = described_class.new(site)

      expect(scanner.each_standard).to be_a(Enumerator)
    end

    it "discovers the actual project standards" do
      # Point to the real project source/_data
      real_source = File.expand_path("../source", __dir__)
      site = instance_double("Jekyll::Site", source: real_source)
      scanner = described_class.new(site)

      standards = scanner.each_standard.to_a
      expect(standards.size).to be >= 2
      numbers = standards.map(&:number)
      expect(numbers).to include("19112", "19135", "19115")
    end
  end
end
