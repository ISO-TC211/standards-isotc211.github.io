# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "Integration: full pipeline" do
  it "loads and processes fixture data end-to-end" do
    data_dir = File.join(FIXTURES_DIR, "sample_standard")
    standard = StandardsGenerator::Standard.new(
      number: "99999", part: "-", edition: "1", data_dir: data_dir
    )

    index = StandardsGenerator::CrossReferenceIndex.new
    classes = standard.load_classes(index)

    # Verify we got both types
    rc = classes.find { |c| c.is_a?(Modspec::NormativeStatementsClass) }
    cc = classes.find { |c| c.is_a?(Modspec::ConformanceClass) }

    expect(rc).not_to be_nil
    expect(cc).not_to be_nil

    # Verify cross-references
    expect(index.tested_by_conf_classes("/req/test-class")).to eq(["/conf/test-class"])
    expect(index.tested_by_tests("/req/test-class/fragment-a")).to eq(["/conf/test-class/test-a"])

    # Verify field policy strips correctly
    policy = standard.field_policy
    data = { "name" => "test", "statement" => "hidden", "description" => "hidden" }
    policy.strip_from!(data)
    expect(data).to eq({ "name" => "test" })

    # Verify page creation
    pages = []
    site = instance_double("Jekyll::Site", source: "/tmp/test", pages: pages)
    factory = StandardsGenerator::PageFactory.new(site)

    factory.create_standard_index_page(standard, classes)
    factory.create_class_page(rc, standard, index)
    factory.create_class_page(cc, standard, index)

    rc.normative_statements.each { |r| factory.create_item_page(r, rc, standard, index) }
    cc.tests.each { |t| factory.create_item_page(t, cc, standard, index) }

    # Standard index + 2 class pages + 2 req items + 2 test items = 7
    expect(pages.size).to eq(7)

    # Verify page paths
    paths = pages.map { |p| p.path.sub(%r{^/tmp/test/?}, "") }
    expect(paths).to include("99999/index.html")
    expect(paths).to include("99999/-/1/req/test-class/index.html")
    expect(paths).to include("99999/-/1/conf/test-class/index.html")
    expect(paths).to include("99999/-/1/req/test-class/fragment-a/index.html")
    expect(paths).to include("99999/-/1/req/test-class/fragment-b/index.html")
    expect(paths).to include("99999/-/1/conf/test-class/test-a/index.html")
    expect(paths).to include("99999/-/1/conf/test-class/test-b/index.html")
  end

  it "processes the real 19115 data without errors" do
    data_dir = File.expand_path("../source/_data/19115/-3/2", __dir__)
    standard = StandardsGenerator::Standard.new(
      number: "19115", part: "-3", edition: "2", data_dir: data_dir
    )

    index = StandardsGenerator::CrossReferenceIndex.new
    classes = standard.load_classes(index)

    expect(classes.size).to be >= 50

    rc_count = classes.count { |c| c.is_a?(Modspec::NormativeStatementsClass) }
    cc_count = classes.count { |c| c.is_a?(Modspec::ConformanceClass) }
    expect(rc_count).to eq(27) # 3 + 1 + 23
    expect(cc_count).to eq(27)

    # Verify the standard metadata loaded
    expect(standard.meta_title).to include("19115-3")
    expect(standard.field_policy.hide?("statement")).to be true
  end
end
