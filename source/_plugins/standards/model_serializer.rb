# frozen_string_literal: true

module StandardsGenerator
  # Converts modspec-ruby model instances to renderable hashes.
  # Centralizes serialization so PageFactory doesn't need to know model internals.
  module ModelSerializer
    module_function

    def serialize(model)
      case model
      when Modspec::NormativeStatementsClass then serialize_rc(model)
      when Modspec::ConformanceClass then serialize_cc(model)
      when Modspec::NormativeStatement then serialize_statement(model)
      when Modspec::ConformanceTest then serialize_test(model)
      else {}
      end
    end

    def serialize_rc(model)
      compact(
        "subject" => model.subject,
        "description" => model.description,
        "guidance" => array_or_nil(model.guidance),
        "dependencies" => array_or_nil(model.dependencies&.map(&:to_s)),
        "requirements" => Array(model.normative_statements).map { |ns| serialize_statement(ns) }
      )
    end

    def serialize_cc(model)
      compact(
        "description" => model.description,
        "guidance" => array_or_nil(model.guidance),
        "dependencies" => array_or_nil(model.dependencies&.map(&:to_s)),
        "target" => model.target.to_s.empty? ? nil : model.target.to_s,
        "tests" => Array(model.tests).map { |t| serialize_test(t) }
      )
    end

    def serialize_statement(model)
      compact(
        "identifier_fragment" => model.identifier.to_s.split("/").last,
        "name" => model.name,
        "statement" => model.statement,
        "subject" => model.subject,
        "guidance" => array_or_nil(model.guidance),
        "examples" => model.respond_to?(:examples) ? array_or_nil(model.examples) : nil
      )
    end

    def serialize_test(model)
      compact(
        "identifier_fragment" => model.identifier.to_s.split("/").last,
        "name" => model.name,
        "targets" => array_or_nil(model.targets&.map(&:to_s)),
        "purpose" => model.purpose,
        "method" => model.test_method,
        "type" => model.type,
        "description" => model.description,
        "guidance" => array_or_nil(model.guidance),
        "examples" => model.respond_to?(:examples) ? array_or_nil(model.examples) : nil
      )
    end

    def compact(hash)
      hash.reject { |_, v| v.nil? }
    end

    def array_or_nil(arr)
      return nil if arr.nil? || (arr.respond_to?(:empty?) && arr.empty?)
      arr
    end
  end
end
