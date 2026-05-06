# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe StandardsGenerator::FieldPolicy do
  describe "#hide?" do
    it "returns true for fields in the hide list" do
      policy = described_class.new(%w[statement description])
      expect(policy.hide?("statement")).to be true
      expect(policy.hide?("description")).to be true
    end

    it "returns false for fields not in the hide list" do
      policy = described_class.new(%w[statement])
      expect(policy.hide?("purpose")).to be false
      expect(policy.hide?("method")).to be false
    end

    it "handles empty hide list" do
      policy = described_class.new([])
      expect(policy.hide?("statement")).to be false
    end

    it "handles nil hide list" do
      policy = described_class.new(nil)
      expect(policy.hide?("statement")).to be false
    end
  end

  describe "#strip_from!" do
    let(:policy) { described_class.new(%w[statement description purpose method]) }

    it "removes top-level hidden fields" do
      data = { "name" => "test", "statement" => "hidden", "description" => "also hidden" }
      policy.strip_from!(data)
      expect(data).to eq({ "name" => "test" })
    end

    it "removes hidden fields from nested normative_statements" do
      data = {
        "name" => "class",
        "normative_statements" => [
          { "name" => "req1", "statement" => "hidden", "guidance" => ["visible"] },
          { "name" => "req2", "description" => "hidden" }
        ]
      }
      policy.strip_from!(data)
      expect(data["normative_statements"][0]).to eq({ "name" => "req1", "guidance" => ["visible"] })
      expect(data["normative_statements"][1]).to eq({ "name" => "req2" })
    end

    it "removes hidden fields from nested tests" do
      data = {
        "tests" => [
          { "name" => "test1", "purpose" => "hidden", "method" => "hidden", "type" => "visible" }
        ]
      }
      policy.strip_from!(data)
      expect(data["tests"][0]).to eq({ "name" => "test1", "type" => "visible" })
    end

    it "removes hidden fields from nested requirements" do
      data = {
        "requirements" => [
          { "name" => "req1", "statement" => "hidden" }
        ]
      }
      policy.strip_from!(data)
      expect(data["requirements"][0]).to eq({ "name" => "req1" })
    end

    it "does not modify hash when no hidden fields present" do
      data = { "name" => "test", "guidance" => ["visible"] }
      policy.strip_from!(data)
      expect(data).to eq({ "name" => "test", "guidance" => ["visible"] })
    end

    it "handles empty hide list without error" do
      policy = described_class.new([])
      data = { "statement" => "visible" }
      policy.strip_from!(data)
      expect(data).to eq({ "statement" => "visible" })
    end
  end
end
