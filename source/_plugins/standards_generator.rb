# frozen_string_literal: true

# Standards generator using modspec-ruby models.
#
# Architecture:
#   SiteScanner         — discovers standard directories under _data/
#   Standard            — loads YAML via modspec-ruby models
#   CrossReferenceIndex — maps identifiers to their types and relationships
#   PageFactory         — creates Jekyll pages from modspec-ruby model instances
#   FieldPolicy         — strips hidden fields from page data

# modspec is installed via Gemfile.modspec into vendor/
# to avoid liquid 4/5 conflict with Jekyll 4.
# __dir__ = build_source/_plugins, so ../../vendor = project_root/vendor
project_root = File.expand_path("../..", __dir__)
%W[#{project_root}/vendor/modspec #{project_root}/vendor/bundle].each do |dir|
  Dir.glob("#{dir}/ruby/*/gems/*/lib").each { |p| $LOAD_PATH.unshift(p) unless $LOAD_PATH.include?(p) }
end

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

      catalog_path = File.join(site.source, '_data', 'standards_catalog.yaml')
      FileUtils.mkdir_p(File.dirname(catalog_path))
      File.write(catalog_path, YAML.dump(catalog.sort_by { |e| e['number'] }))
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

Jekyll::Hooks.register :site, :after_reset do |site|
  StandardsGenerator.generate(site)
end
