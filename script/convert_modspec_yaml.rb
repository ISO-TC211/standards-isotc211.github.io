#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts ISO 19115-3 Metanorma YAML (groups/scopes format with full URIs)
# to standards.isotc211.org format (normative_statements_classes with relative paths).
#
# Usage: ruby script/convert_modspec_yaml.rb

require "yaml"
require "fileutils"

SOURCE_DIR = File.expand_path("../../../mn/iso-19115-3/sources/ed2/sections/tables/yaml", __dir__)
OUTPUT_DIR = File.expand_path("../source/_data/19115/-3/2", __dir__)

URI_PREFIX = %r{https://standards\.isotc211\.org/\d+/-?\d+/\d+}

def strip_prefix(uri)
  uri.to_s.sub(URI_PREFIX, "")
end

def compact_hash(hash)
  hash.reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
end

def flatten_field(value)
  return nil unless value
  value.is_a?(Array) ? value.join("\n") : value
end

# -- RC (Requirements Classes) conversion --

def convert_rc_scope(scope)
  compact_hash(
    "identifier" => strip_prefix(scope["identifier"]),
    "name" => scope["name"],
    "subject" => scope["subject"],
    "dependencies" => compact_deps(scope["dependencies"]),
    "normative_statements" => convert_list(scope["requirements"], method(:convert_req))
  )
end

def convert_req(req)
  compact_hash(
    "identifier" => strip_prefix(req["identifier"]),
    "name" => req["name"],
    "subject" => req["subject"],
    "dependencies" => compact_deps(req["dependencies"])
  )
end

# -- CC (Conformance Classes) conversion --

def convert_cc_scope(scope)
  compact_hash(
    "identifier" => strip_prefix(scope["identifier"]),
    "name" => scope["name"] || scope["title"],
    "target" => scope["target"] ? strip_prefix(scope["target"]) : nil,
    "subject" => scope["subject"],
    "dependencies" => compact_deps(scope["dependencies"]),
    "tests" => convert_list(scope["tests"], method(:convert_test))
  )
end

def convert_test(test)
  compact_hash(
    "identifier" => strip_prefix(test["identifier"]),
    "name" => test["name"],
    "targets" => test["targets"]&.map { |t| strip_prefix(t) }&.reject(&:empty?),
    "type" => test["type"],
    "dependencies" => compact_deps(test["dependencies"])
  )
end

# -- Helpers --

def compact_deps(deps)
  return nil unless deps
  stripped = deps.map { |d| strip_prefix(d) }.reject(&:empty?)
  stripped.empty? ? nil : stripped
end

def convert_list(items, converter)
  return nil unless items
  converted = items.map { |item| converter.call(item) }
  converted.empty? ? nil : converted
end

def load_scopes(filename)
  data = YAML.safe_load_file(File.join(SOURCE_DIR, filename), permitted_classes: [Symbol])
  return [] unless data&.dig("groups")

  data["groups"].flat_map { |g| g["scopes"] || [] }
end

# -- Main --

FileUtils.mkdir_p(OUTPUT_DIR)

# Map of section → source files for RC and CC
SECTIONS = {
  "06" => {
    rc: %w[19115-12-rc.yaml],
    cc: %w[19115-12-cc.yaml]
  },
  "07" => {
    rc: %w[19115-xml-min-rc.yaml],
    cc: %w[19115-xml-min-cc.yaml]
  },
  "08" => {
    rc: %w[19115-1-xml-rc.yaml 19115-2-xml-rc.yaml 19115-3-xml-rc.yaml 191xx-xml-rc.yaml extended-xml-rc.yaml],
    cc: %w[19115-1-xml-cc.yaml 19115-2-xml-cc.yaml 19115-3-xml-cc.yaml 191xx-xml-cc.yaml extended-xml-cc.yaml]
  }
}

SECTIONS.each do |section, files|
  [:rc, :cc].each do |type|
    all_classes = files[type].flat_map do |f|
      scopes = load_scopes(f)
      converter = type == :rc ? method(:convert_rc_scope) : method(:convert_cc_scope)
      scopes.map { |scope| converter.call(scope) }
    end

    key = type == :rc ? "normative_statements_classes" : "conformance_classes"
    output = { key => all_classes }
    out_path = File.join(OUTPUT_DIR, "#{section}-#{type}.yaml")
    File.write(out_path, YAML.dump(output))
    puts "Wrote #{out_path} (#{all_classes.size} classes)"
  end
end

puts "\nConversion complete!"
