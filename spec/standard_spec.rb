# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe StandardsGenerator::Standard do
  let(:data_dir) { File.join(FIXTURES_DIR, "sample_standard") }
  let(:standard) { described_class.new(number: "99999", part: "-", edition: "1", data_dir: data_dir) }

  describe "#initialize" do
    it "sets number, part, edition" do
      expect(standard.number).to eq("99999")
      expect(standard.part).to eq("-")
      expect(standard.edition).to eq(1)
    end

    it "computes uri_base from number/part/edition" do
      expect(standard.uri_base).to eq("99999/-/1")
    end
  end

  describe "metadata accessors" do
    it "reads meta_title from _meta.yaml" do
      expect(standard.meta_title).to eq("ISO 99999:2025 Test Standard")
    end

    it "reads label" do
      expect(standard.label).to eq("ISO 99999:2025")
    end

    it "reads subtitle" do
      expect(standard.subtitle).to eq("Test standard subtitle")
    end

    it "reads description" do
      expect(standard.meta_description).to eq("A test standard for specs.\n")
    end
  end

  describe "#field_policy" do
    it "creates FieldPolicy from hide_fields in _meta.yaml" do
      policy = standard.field_policy
      expect(policy).to be_a(StandardsGenerator::FieldPolicy)
      expect(policy.hide?("statement")).to be true
      expect(policy.hide?("description")).to be true
      expect(policy.hide?("purpose")).to be false
    end
  end

  describe "#load_classes" do
    let(:index) { StandardsGenerator::CrossReferenceIndex.new }
    let(:classes) { standard.load_classes(index) }

    it "loads requirements and conformance classes" do
      expect(classes.size).to eq(2)
    end

    it "returns a NormativeStatementsClass" do
      rc = classes.find { |c| c.is_a?(Modspec::NormativeStatementsClass) }
      expect(rc).not_to be_nil
      expect(rc.identifier.to_s).to eq("/req/test-class")
      expect(rc.name).to eq("Test requirements class")
    end

    it "returns a ConformanceClass" do
      cc = classes.find { |c| c.is_a?(Modspec::ConformanceClass) }
      expect(cc).not_to be_nil
      expect(cc.identifier.to_s).to eq("/conf/test-class")
      expect(cc.name).to eq("Test conformance class")
    end

    it "registers classes in the cross-reference index" do
      standard.load_classes(index)
      expect(index.tested_by_conf_classes("/req/test-class")).to include("/conf/test-class")
    end
  end
end
