# frozen_string_literal: true

# Standards generator using modspec-ruby models.
#
# Architecture:
#   SiteScanner         — discovers standard directories under _data/
#   Standard            — loads YAML via modspec-ruby models
#   CrossReferenceIndex — maps identifiers to their types and relationships
#   PageFactory         — creates Jekyll pages from modspec-ruby model instances
#   FieldPolicy         — strips hidden fields from page data

require "modspec"

Dir[File.join(__dir__, 'standards', '*.rb')].sort.each { |f| require f }

module StandardsGenerator
  class << self
    def generate(site)
      scanner = SiteScanner.new(site)
      factory = PageFactory.new(site)
      catalog = []

      scanner.each_standard do |std|
        index = CrossReferenceIndex.new
        classes = std.load_classes(index)

        factory.create_standard_index_page(std, classes)

        catalog << build_catalog_entry(std, classes)

        classes.each do |klass|
          factory.create_class_page(klass, std, index)

          children = klass.is_a?(Modspec::NormativeStatementsClass) \
            ? klass.normative_statements \
            : klass.tests

          Array(children).each do |child|
            factory.create_item_page(child, klass, std, index)
          end
        end
      end

      # Phase 2: placeholder standards from tc211_standards.yaml inventory
      tc211_path = File.join(site.source, "_data", "tc211_standards.yaml")
      if File.exist?(tc211_path)
        tc211_entries = YAML.safe_load_file(tc211_path, permitted_classes: [Symbol]) || []
        known_labels = catalog.map { |e| e["label"] }.to_set

        tc211_entries.each do |entry|
          next if known_labels.include?(entry["reference"])

          factory.create_placeholder_page(entry)

          std_key = entry["part"] ? "#{entry['number']}-#{entry['part']}" : entry["number"]
          catalog << {
            "number" => std_key,
            "label" => entry["reference"],
            "subtitle" => entry["title"],
            "url" => "/#{std_key}/",
            "edition" => entry["edition"],
            "req_count" => 0,
            "conf_count" => 0,
            "populated" => false,
            "iso_standard_url" => "https://www.iso.org/standard/#{entry['iso_id']}.html"
          }
        end
      end

      site.data['standards_catalog'] = catalog.sort_by { |e| e['number'] }
    end

    private

    def build_catalog_entry(std, classes)
      req_count = classes.count { |k| k.is_a?(Modspec::NormativeStatementsClass) }
      conf_count = classes.count { |k| k.is_a?(Modspec::ConformanceClass) }

      entry = {
        'number' => std.number,
        'label' => std.label || "ISO #{std.number}",
        'subtitle' => std.subtitle,
        'url' => "/#{std.number}/",
        'edition' => std.edition,
        'req_count' => req_count,
        'conf_count' => conf_count
      }
      entry['iso_standard_url'] = std.iso_standard_url if std.iso_standard_url
      entry['iso_preview_url'] = std.iso_preview_url if std.iso_preview_url
      entry['populated'] = req_count > 0 || conf_count > 0

      first_rc = classes.find { |k| k.is_a?(Modspec::NormativeStatementsClass) && Array(k.normative_statements).any? }
      first_cc = classes.find { |k| k.is_a?(Modspec::ConformanceClass) }

      if first_cc
        entry['example_conf_uri'] = "/#{std.uri_base}#{first_cc.identifier}/"
        entry['example_conf_path'] = "#{std.uri_base}#{first_cc.identifier}"
      end

      if first_rc
        first_req = Array(first_rc.normative_statements).first
        if first_req
          entry['example_req_uri'] = "/#{std.uri_base}#{first_req.identifier}/"
          entry['example_req_path'] = "#{std.uri_base}#{first_req.identifier}"
        end
      end

      entry
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  StandardsGenerator.generate(site)
end
