# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe StandardsGenerator::PageFactory do
  # Minimal mock site
  let(:pages) { [] }
  let(:site) { instance_double("Jekyll::Site", source: "/tmp/test_source", pages: pages) }
  let(:factory) { described_class.new(site) }

  let(:standard) do
    StandardsGenerator::Standard.new(
      number: "99999", part: "-", edition: "1",
      data_dir: File.join(FIXTURES_DIR, "sample_standard")
    )
  end

  let(:index) { StandardsGenerator::CrossReferenceIndex.new }
  let(:classes) { standard.load_classes(index) }

  let(:rc) { classes.find { |c| c.is_a?(Modspec::NormativeStatementsClass) } }
  let(:cc) { classes.find { |c| c.is_a?(Modspec::ConformanceClass) } }

  describe "#create_standard_index_page" do
    before { factory.create_standard_index_page(standard, classes) }

    it "creates a page at the standard number path" do
      page = pages.first
      expect(page.path).to end_with("99999/index.html")
    end

    it "sets the standard_index layout" do
      page = pages.first
      expect(page.data["layout"]).to eq("standard_index")
    end

    it "includes req and conf class lists" do
      page = pages.first
      expect(page.data["req_classes"].size).to eq(1)
      expect(page.data["conf_classes"].size).to eq(1)
    end
  end

  describe "#create_class_page" do
    it "creates a requirements class page" do
      factory.create_class_page(rc, standard, index)
      page = pages.last
      expect(page.data["page_type"]).to eq("requirements_class")
      expect(page.data["identifier"]).to eq("/req/test-class")
      expect(page.data["layout"]).to eq("provision_class")
    end

    it "creates a conformance class page" do
      factory.create_class_page(cc, standard, index)
      page = pages.last
      expect(page.data["page_type"]).to eq("conformance_class")
      expect(page.data["identifier"]).to eq("/conf/test-class")
    end

    it "includes cross-references" do
      factory.create_class_page(rc, standard, index)
      page = pages.last
      xrefs = page.data["xrefs"]
      expect(xrefs["tested_by"]).to include("/conf/test-class")
    end

    it "strips hidden fields from data" do
      factory.create_class_page(rc, standard, index)
      page = pages.last
      expect(page.data["data"]).not_to have_key("description")
    end
  end

  describe "#create_item_page" do
    it "creates an individual requirement page" do
      req = rc.normative_statements.first
      factory.create_item_page(req, rc, standard, index)
      page = pages.last
      expect(page.data["page_type"]).to eq("requirement")
      expect(page.data["identifier"]).to eq("/req/test-class/fragment-a")
    end

    it "creates an individual test page" do
      test = cc.tests.first
      factory.create_item_page(test, cc, standard, index)
      page = pages.last
      expect(page.data["page_type"]).to eq("test")
      expect(page.data["identifier"]).to eq("/conf/test-class/test-a")
    end

    it "includes parent identifier" do
      req = rc.normative_statements.first
      factory.create_item_page(req, rc, standard, index)
      page = pages.last
      expect(page.data["parent_identifier"]).to eq("/req/test-class")
    end

    it "includes cross-references for requirements (tested_by tests)" do
      req = rc.normative_statements.first
      factory.create_item_page(req, rc, standard, index)
      page = pages.last
      xrefs = page.data["xrefs"]
      expect(xrefs["tested_by"]).to include(hash_including("id" => "/conf/test-class/test-a"))
    end

    it "includes cross-references for tests (targets requirements)" do
      test = cc.tests.first
      factory.create_item_page(test, cc, standard, index)
      page = pages.last
      xrefs = page.data["xrefs"]
      expect(xrefs["targets"]).to include(hash_including("id" => "/req/test-class/fragment-a"))
    end

    it "strips hidden fields from item data" do
      req = rc.normative_statements.first
      factory.create_item_page(req, rc, standard, index)
      page = pages.last
      expect(page.data["data"]).not_to have_key("statement")
    end
  end
end
