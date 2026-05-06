#!/usr/bin/env ruby
# frozen_string_literal: true

# Maintains source/_data/tc211_standards.yaml — the inventory of all published
# ISO/TC 211 standards from ISO public metadata.
#
# Fetches the latest data, compares against the existing inventory, and writes
# the updated file. Reports new entries for GHA to create PRs.
#
# Used by .github/workflows/discover_standards.yml on a weekly schedule.

require "open-uri"
require "json"
require "yaml"
require "set"

TC_URL = "https://isopublicstorageprod.blob.core.windows.net/opendata/_latest/" \
         "iso_technical_committees/json/iso_technical_committees.jsonl"
DELIVERABLES_URL = "https://isopublicstorageprod.blob.core.windows.net/opendata/_latest/" \
                   "iso_deliverables_metadata/json/iso_deliverables_metadata.jsonl"

DATA_DIR = File.expand_path("../source/_data", __dir__)
YAML_PATH = File.join(DATA_DIR, "tc211_standards.yaml")
PENDING_PATH = File.join(DATA_DIR, "tc211_standards_pending.yaml")

REFERENCE_RE = %r{\A(?:ISO|ISO/TS|ISO/TR)\s+(\d+)(?:-(\d+))?:(\d{4})}
SUPPLEMENT_RE = %r{/(Amd|Cor)\s}

def stream_jsonl(url)
  URI.open(url) do |io|
    io.each_line do |line|
      record = JSON.parse(line) rescue next
      yield record
    end
  end
end

def tc211_reference
  ref = nil
  stream_jsonl(TC_URL) do |r|
    if r["reference"] == "ISO/TC 211"
      ref = r["reference"]
      break
    end
  end
  ref
end

def parse_reference(ref)
  return nil if ref&.match?(SUPPLEMENT_RE)
  m = ref&.match(REFERENCE_RE)
  return nil unless m
  {
    std_key: m[2] ? "#{m[1]}-#{m[2]}" : m[1],
    number: m[1],
    part: m[2],
    year: m[3].to_i
  }
end

def entry_from_deliverable(deliverable)
  parsed = parse_reference(deliverable["reference"])
  return nil unless parsed
  {
    "reference" => deliverable["reference"],
    "title" => deliverable.dig("title", "en").to_s,
    "number" => parsed[:number],
    "part" => parsed[:part],
    "edition" => deliverable["edition"],
    "type" => deliverable["deliverableType"],
    "iso_id" => deliverable["id"],
    "published" => deliverable["publicationDate"],
    "pending" => false
  }
end

# --- Main ---

tc211_ref = tc211_reference
abort "Error: could not find ISO/TC 211 in technical committees data." unless tc211_ref

# Collect latest published non-supplement non-replaced editions
latest = {}
stream_jsonl(DELIVERABLES_URL) do |r|
  next unless r["ownerCommittee"] == tc211_ref
  next unless r["publicationDate"]
  next if r["replacedBy"] && !r["replacedBy"].empty?
  next if r["reference"]&.match?(SUPPLEMENT_RE)

  parsed = parse_reference(r["reference"])
  next unless parsed

  key = parsed[:std_key]
  existing = latest[key]
  if !existing ||
     r["edition"] > existing["edition"] ||
     (r["edition"] == existing["edition"] && r["publicationDate"] > existing["publicationDate"])
    latest[key] = r
  end
end

# Build sorted inventory
inventory = latest.values
  .filter_map { |r| entry_from_deliverable(r) }
  .sort_by { |e| [e["number"].to_i, e["part"] || "\xff", e["edition"]] }

# Apply pending list
pending_refs = if File.exist?(PENDING_PATH)
  Set.new((YAML.safe_load_file(PENDING_PATH) || []))
else
  Set.new
end
inventory.each { |e| e["pending"] = true if pending_refs.include?(e["reference"]) }

# Identify new entries against existing inventory
existing_refs = if File.exist?(YAML_PATH)
  Set.new((YAML.safe_load_file(YAML_PATH) || []).map { |e| e["reference"] })
else
  Set.new
end

new_entries = inventory.reject { |e| existing_refs.include?(e["reference"]) }

# Write updated inventory
FileUtils.mkdir_p(DATA_DIR)
File.write(YAML_PATH, YAML.dump(inventory))

# Output for GHA
if new_entries.any?
  puts "NEW_STANDARDS_COUNT=#{new_entries.length}"
  new_entries.each { |e| puts "- **#{e['reference']}** — #{e['title']}" }
else
  puts "NEW_STANDARDS_COUNT=0"
end
