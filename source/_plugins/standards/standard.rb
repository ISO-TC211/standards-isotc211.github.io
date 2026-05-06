# frozen_string_literal: true

module StandardsGenerator
  class Standard
    attr_reader :number, :part, :edition, :uri_base

    def initialize(number:, part:, edition:, data_dir:)
      @number = number
      @part = part
      @edition = edition
      @data_dir = data_dir
      @uri_base = "#{number}/#{part}/#{edition}"
    end

    def meta_title
      meta['title']
    end

    def iso_standard_url
      meta['iso_standard_url']
    end

    def iso_preview_url
      meta['iso_preview_url']
    end

    def meta_description
      meta['description']
    end

    def label
      meta['label']
    end

    def subtitle
      meta['subtitle']
    end

    def edition
      meta['edition']
    end

    def field_policy
      @field_policy ||= FieldPolicy.new(meta.fetch('hide_fields', []))
    end

    # Loads all NormativeStatementsClass and ConformanceClass instances
    # from YAML data files, registering each in the cross-reference index.
    def load_classes(index)
      classes = []

      rc_files.each do |yaml_file|
        data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol]) || {}
        Array(data['normative_statements_classes']).each do |cls_data|
          rc = Modspec::NormativeStatementsClass.from_yaml(YAML.dump(cls_data))
          classes << rc
          index.register_rc(rc)
        end
      end

      cc_files.each do |yaml_file|
        data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol]) || {}
        Array(data['conformance_classes']).each do |cls_data|
          cc = Modspec::ConformanceClass.from_yaml(YAML.dump(cls_data))
          classes << cc
          index.register_cc(cc)
        end
      end

      classes
    end

    private

    def meta
      @meta ||= begin
        meta_path = File.join(@data_dir, '_meta.yaml')
        if File.exist?(meta_path)
          YAML.safe_load_file(meta_path, permitted_classes: [Symbol]) || {}
        else
          {}
        end
      end
    end

    def rc_files
      Dir.glob(File.join(@data_dir, '*-rc.yaml')).sort
    end

    def cc_files
      Dir.glob(File.join(@data_dir, '*-cc.yaml')).sort
    end
  end
end
