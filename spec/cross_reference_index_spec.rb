# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe StandardsGenerator::CrossReferenceIndex do
  let(:index) { described_class.new }

  def make_rc(identifier, statements = [])
    rc_data = {
      "identifier" => identifier,
      "name" => "Test RC",
      "normative_statements" => statements.map do |s|
        { "identifier" => s, "name" => "Statement" }
      end
    }
    Modspec::NormativeStatementsClass.from_yaml(YAML.dump(rc_data))
  end

  def make_cc(identifier, target: nil, tests: [])
    cc_data = {
      "identifier" => identifier,
      "name" => "Test CC",
      "target" => target,
      "tests" => tests.map do |t|
        { "identifier" => t[:id], "name" => "Test", "targets" => t[:targets] || [] }
      end
    }
    Modspec::ConformanceClass.from_yaml(YAML.dump(cc_data))
  end

  describe "registering requirements classes" do
    it "maps rc identifier to :req_class" do
      rc = make_rc("/req/foo")
      index.register_rc(rc)
      expect(index.dep_type("/req/foo")).to eq("req_class")
    end

    it "maps individual requirements to :requirement" do
      rc = make_rc("/req/foo", ["/req/foo/bar"])
      index.register_rc(rc)
      expect(index.dep_type("/req/foo/bar")).to eq("requirement")
    end
  end

  describe "registering conformance classes" do
    it "maps cc identifier to :conf_class" do
      cc = make_cc("/conf/foo")
      index.register_cc(cc)
      expect(index.dep_type("/conf/foo")).to eq("conf_class")
    end

    it "maps individual tests to :conf_test" do
      cc = make_cc("/conf/foo", tests: [{ id: "/conf/foo/test1", targets: [] }])
      index.register_cc(cc)
      expect(index.dep_type("/conf/foo/test1")).to eq("conf_test")
    end
  end

  describe "req↔conf cross-references" do
    it "finds conf classes that target a requirements class" do
      rc = make_rc("/req/foo")
      cc = make_cc("/conf/foo", target: "/req/foo")

      index.register_rc(rc)
      index.register_cc(cc)

      expect(index.tested_by_conf_classes("/req/foo")).to eq(["/conf/foo"])
    end

    it "finds tests that target a specific requirement" do
      rc = make_rc("/req/foo", ["/req/foo/bar"])
      cc = make_cc("/conf/foo", target: "/req/foo",
                    tests: [{ id: "/conf/foo/test1", targets: ["/req/foo/bar"] }])

      index.register_rc(rc)
      index.register_cc(cc)

      expect(index.tested_by_tests("/req/foo/bar")).to eq(["/conf/foo/test1"])
    end

    it "returns empty array for unregistered identifiers" do
      expect(index.tested_by_conf_classes("/req/nonexistent")).to eq([])
      expect(index.tested_by_tests("/req/nonexistent")).to eq([])
    end
  end

  describe "#dep_type" do
    it "falls back to path-based heuristics for unknown identifiers" do
      expect(index.dep_type("/conf/unknown")).to eq("conf_test")
      expect(index.dep_type("/req/unknown")).to eq("requirement")
    end
  end

  describe "#classify_deps" do
    it "classifies a list of dependency identifiers" do
      rc = make_rc("/req/a")
      cc = make_cc("/conf/a", target: "/req/a")

      index.register_rc(rc)
      index.register_cc(cc)

      deps = index.classify_deps(["/req/a", "/conf/a"])
      expect(deps).to eq([
        { "id" => "/req/a", "kind" => "req_class" },
        { "id" => "/conf/a", "kind" => "conf_class" }
      ])
    end

    it "filters nil and empty strings" do
      deps = index.classify_deps(["/req/a", nil, "", "/conf/b"])
      expect(deps.size).to eq(2)
    end
  end
end
