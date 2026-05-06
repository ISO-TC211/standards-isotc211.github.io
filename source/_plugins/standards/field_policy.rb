# frozen_string_literal: true

module StandardsGenerator
  class FieldPolicy
    attr_reader :hidden

    def initialize(hide_fields)
      @hidden = Array(hide_fields).map(&:to_s)
    end

    def hide?(field_name)
      @hidden.include?(field_name.to_s)
    end

    # Strip hidden fields from a hash (mutates in place).
    # Used on the rendered data hash, not on modspec-ruby models.
    def strip_from!(hash)
      @hidden.each { |f| hash.delete(f) }
      %w[normative_statements tests requirements].each do |key|
        (hash[key] || []).each { |item| @hidden.each { |f| item.delete(f) } }
      end
    end
  end
end
