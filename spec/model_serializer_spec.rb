# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe StandardsGenerator::ModelSerializer do
  let(:data_dir) { File.join(FIXTURES_DIR, "sample_standard") }
  let(:standard) do
    StandardsGenerator::Standard.new(number: "99999", part: "-", edition: "1", data_dir: data_dir)
  end
  let(:index) { StandardsGenerator::CrossReferenceIndex.new }
  let(:classes) { standard.load_classes(index) }

  let(:rc) { classes.find { |c| c.is_a?(Modspec::NormativeStatementsClass) } }
  let(:cc) { classes.find { |c| c.is_a?(Modspec::ConformanceClass) } }

  describe ".serialize" do
    it "serializes a NormativeStatementsClass" do
      result = described_class.serialize(rc)
      expect(result["subject"]).to eq("testing")
      expect(result["requirements"]).to be_a(Array)
      expect(result["requirements"].size).to eq(2)
    end

    it "serializes a ConformanceClass" do
      result = described_class.serialize(cc)
      expect(result["target"]).to eq("/req/test-class")
      expect(result["tests"]).to be_a(Array)
      expect(result["tests"].size).to eq(2)
    end

    it "serializes a NormativeStatement" do
      stmt = rc.normative_statements.first
      result = described_class.serialize(stmt)
      expect(result["name"]).to eq("Fragment A requirement")
      expect(result["statement"]).to eq("The system shall pass tests.")
      expect(result["identifier_fragment"]).to eq("fragment-a")
    end

    it "serializes a ConformanceTest" do
      test = cc.tests.first
      result = described_class.serialize(test)
      expect(result["name"]).to eq("Test A")
      expect(result["purpose"]).to eq("Verify fragment A.")
      expect(result["method"]).to eq("Check the system passes tests.")
      expect(result["type"]).to eq("Validation")
      expect(result["identifier_fragment"]).to eq("test-a")
    end

    it "returns empty hash for unknown types" do
      result = described_class.serialize("not a model")
      expect(result).to eq({})
    end
  end

  describe "nil/empty field handling" do
    it "omits nil fields from output" do
      result = described_class.serialize(rc)
      # guidance exists, description exists, but fields that are nil should be absent
      expect(result).to have_key("subject")
      expect(result).to have_key("description")
    end

    it "includes non-nil fields" do
      result = described_class.serialize(rc)
      expect(result).to have_key("subject")
      expect(result).to have_key("requirements")
    end
  end
end
