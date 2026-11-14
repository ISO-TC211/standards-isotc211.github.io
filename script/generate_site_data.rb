# frozen_string_literal: true

# Generates src/data/standards-catalog.json + standards-pages.json from the
# modspec YAML data, replacing the Jekyll standards_generator + PageFactory.
# Reuses SiteScanner/Standard/CrossReferenceIndex/ModelSerializer/FieldPolicy
# verbatim; only the page-emission differs (JSON instead of Jekyll pages).

require "yaml"
require "json"
require "set"
require "modspec"
require "fileutils"

SRC = File.expand_path("../source", __dir__)
Dir[File.join(__dir__, "..", "source", "_plugins", "standards", "*.rb")].sort.each { |f| require f }
require File.join(SRC, "_plugins", "standards", "site_scanner") rescue nil

module StandardsGenerator
  class SiteScanner2
    def initialize(data_dir)
      @data_dir = data_dir
    end

    def each_standard
      return enum_for(:each_standard) unless block_given?
      Dir.glob(File.join(@data_dir, '*')).each do |std_dir|
        next unless File.directory?(std_dir)
        number = File.basename(std_dir)
        Dir.glob(File.join(std_dir, '*')).each do |part_dir|
          next unless File.directory?(part_dir)
          part = File.basename(part_dir)
          Dir.glob(File.join(part_dir, '*')).each do |edition_dir|
            next unless File.directory?(edition_dir)
            yield Standard.new(number: number, part: part, edition: File.basename(edition_dir), data_dir: edition_dir)
          end
        end
      end
    end
  end

  class CrossReferenceIndex2
    def initialize
      @types = {}
      @tests_by_statement = Hash.new { |h, k| h[k] = [] }
      @tests_by_class = Hash.new { |h, k| h[k] = [] }
    end

    def register_rc(rc)
      @types[rc.identifier.to_s] = 'req_class'
    end

    def register_cc(cc)
      @types[cc.identifier.to_s] = 'conf_class'
      target = cc.target.to_s
      @tests_by_class[target] << cc.identifier.to_s unless target.empty?
      Array(cc.tests).each do |t|
        @tests_by_class[cc.identifier.to_s] << cc.identifier.to_s
      end
    end

    def register_statement(ns)
      @types[ns.identifier.to_s] = 'requirement'
    end

    def register_test(t)
      @types[t.identifier.to_s] = 'conf_test'
      Array(t.targets).each do |target|
        target_s = target.to_s
        kind = @types[target_s] || 'requirement'
        @tests_by_statement[target_s] << t.identifier.to_s if kind == 'requirement'
      end
    end

    def dep_type(id) = @types[id]
    def tested_by_tests(id) = @tests_by_statement[id]
    def tested_by_conf_classes(id) = @tests_by_class[id]
    def classify_deps(deps) = deps.map { |d| { 'id' => d, 'kind' => @types[d] || 'unknown' } }
  end
end

# Standard/FieldPolicy/ModelSerializer/CrossReferenceIndex come from the plugins
require File.expand_path("../source/_plugins/standards/standard.rb", __dir__)
require File.expand_path("../source/_plugins/standards/field_policy.rb", __dir__)
require File.expand_path("../source/_plugins/standards/model_serializer.rb", __dir__)
require File.expand_path("../source/_plugins/standards/cross_reference_index.rb", __dir__)

scanner = StandardsGenerator::SiteScanner2.new(File.join(SRC, "_data"))
catalog = []
pages = []

scanner.each_standard do |std|
  index = StandardsGenerator::CrossReferenceIndex.new
  classes = std.load_classes(index)

  # register statements/tests for xref resolution
  classes.each do |klass|
    children = klass.is_a?(Modspec::NormativeStatementsClass) ? klass.normative_statements : klass.tests
    Array(children).each do |child|
          end
  end

  # standard index page
  req_classes = classes.select { |k| k.is_a?(Modspec::NormativeStatementsClass) }.map { |k| { 'identifier' => k.identifier.to_s, 'name' => k.name } }
  conf_classes = classes.select { |k| k.is_a?(Modspec::ConformanceClass) }.map { |k| { 'identifier' => k.identifier.to_s, 'name' => k.name } }
  std_data = {
    'layout' => 'standard_index', 'title' => std.meta_title, 'standard_number' => std.number,
    'description' => std.meta_description, 'uri_base' => std.uri_base,
    'req_classes' => req_classes, 'conf_classes' => conf_classes
  }
  std_data['iso_standard_url'] = std.iso_standard_url if std.iso_standard_url
  std_data['iso_preview_url'] = std.iso_preview_url if std.iso_preview_url
  pages << { 'path' => std.number.to_s, 'kind' => 'standard_index', 'data' => std_data }

  # class + item pages
  classes.each do |klass|
    ident = klass.identifier.to_s
    is_req = klass.is_a?(Modspec::NormativeStatementsClass)
    render_data = StandardsGenerator::ModelSerializer.serialize(klass)
    std.field_policy.strip_from!(render_data)
    xrefs = {}
    if is_req
        tested = index.tested_by_conf_classes(ident)
      xrefs['tested_by'] = tested unless tested.empty?
    else
      target = klass.target.to_s
      xrefs['requirements_class'] = target unless target.empty?
    end
    deps = Array(klass.dependencies).map(&:to_s).reject(&:empty?)
    xrefs['dependencies'] = index.classify_deps(deps) unless deps.empty?
    cdata = {
      'layout' => 'provision_class', 'title' => klass.name,
      'page_type' => is_req ? 'requirements_class' : 'conformance_class',
      'identifier' => ident, 'uri_base' => std.uri_base,
      'standard_title' => std.meta_title, 'data' => render_data, 'xrefs' => xrefs
    }
    cdata['iso_standard_url'] = std.iso_standard_url if std.iso_standard_url
    cdata['iso_preview_url'] = std.iso_preview_url if std.iso_preview_url
    pages << { 'path' => "#{std.uri_base}#{ident}", 'kind' => 'provision_class', 'data' => cdata }

    children = klass.is_a?(Modspec::NormativeStatementsClass) ? klass.normative_statements : klass.tests
    Array(children).each do |child|
      cident = child.identifier.to_s
      child_is_req = child.is_a?(Modspec::NormativeStatement)
      c_render = StandardsGenerator::ModelSerializer.serialize(child)
      std.field_policy.strip_from!(c_render)
      item_xrefs = {}
      if child_is_req
        tested = index.tested_by_tests(cident)
        item_xrefs['tested_by'] = tested.map { |tid| { 'id' => tid, 'kind' => 'test' } }
      else
        targets = Array(child.targets).map(&:to_s).reject(&:empty?)
        item_xrefs['targets'] = targets.map { |t| { 'id' => t, 'kind' => index.dep_type(t) } }
      end
      idata = {
        'layout' => 'provision_class', 'title' => child.name,
        'page_type' => child_is_req ? 'requirement' : 'test',
        'identifier' => cident, 'uri_base' => std.uri_base,
        'parent_identifier' => ident, 'parent_title' => klass.name,
        'standard_title' => std.meta_title, 'data' => c_render, 'xrefs' => item_xrefs
      }
      idata['iso_standard_url'] = std.iso_standard_url if std.iso_standard_url
      idata['iso_preview_url'] = std.iso_preview_url if std.iso_preview_url
      pages << { 'path' => "#{std.uri_base}#{cident}", 'kind' => 'provision_class', 'data' => idata }
    end
  end

  req_count = classes.count { |k| k.is_a?(Modspec::NormativeStatementsClass) }
  conf_count = classes.count { |k| k.is_a?(Modspec::ConformanceClass) }
  entry = {
    'number' => std.number, 'label' => std.label || "ISO #{std.number}", 'subtitle' => std.subtitle,
    'url' => "/#{std.number}/", 'edition' => std.edition,
    'req_count' => req_count, 'conf_count' => conf_count, 'populated' => req_count > 0 || conf_count > 0
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
  catalog << entry
end

# placeholders from TC211 inventory
tc211_path = File.join(SRC, "_data", "tc211_standards.yaml")
pending_path = File.join(SRC, "_data", "tc211_standards_pending.yaml")
pending_refs = File.exist?(pending_path) ? Set.new(YAML.safe_load_file(pending_path, permitted_classes: [Symbol]) || []) : Set.new
known_labels = catalog.map { |e| e['label'] }.to_set
if File.exist?(tc211_path)
  YAML.safe_load_file(tc211_path, permitted_classes: [Symbol]).each do |entry|
    next if known_labels.include?(entry['reference'])
    ref = entry['reference']
    pending = entry['pending'] || pending_refs.any? { |p| ref == p || ref.start_with?("#{p}:") }
    std_key = entry['part'] ? "#{entry['number']}-#{entry['part']}" : entry['number']
    data = {
      'layout' => 'standard_index', 'title' => entry['title'], 'standard_number' => std_key,
      'description' => pending ? 'This standard does not specify requirements that utilize the ISO/TC 211 Harmonized URI scheme.' :
        'This standard does not yet have machine-readable requirements or conformance data on this site.',
      'uri_base' => "#{entry['number']}/-#{entry['part'] || ''}/#{entry['edition']}/",
      'req_classes' => [], 'conf_classes' => [], 'pending' => pending,
      'iso_standard_url' => "https://www.iso.org/standard/#{entry['iso_id']}.html"
    }
    pages << { 'path' => std_key, 'kind' => 'placeholder', 'data' => data }
    catalog << {
      'number' => std_key, 'label' => entry['reference'], 'subtitle' => entry['title'],
      'url' => "/#{std_key}/", 'edition' => entry['edition'], 'req_count' => 0, 'conf_count' => 0,
      'populated' => false, 'pending' => pending,
      'iso_standard_url' => "https://www.iso.org/standard/#{entry['iso_id']}.html"
    }
  end
end

FileUtils.mkdir_p(File.join(__dir__, "..", "src", "data"))
File.write(File.join(__dir__, "..", "src", "data", "standards-catalog.json"), JSON.pretty_generate(catalog.sort_by { |e| e['number'] }))
File.write(File.join(__dir__, "..", "src", "data", "standards-pages.json"), JSON.pretty_generate(pages.sort_by { |p| p['path'] }))
puts "standards-catalog.json: #{catalog.size} entries; standards-pages.json: #{pages.size} pages"
