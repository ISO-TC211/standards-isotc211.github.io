# frozen_string_literal: true

module StandardsGenerator
  class PageFactory
    def initialize(site)
      @site = site
    end

    def create_class_page(klass, std, index)
      data = class_page_data(klass, std, index)
      page = Jekyll::PageWithoutAFile.new(@site, @site.source, '', "#{data['page_path']}/index.html")
      page.data = data
      page.content = ''
      @site.pages << page
    end

    def create_item_page(item, parent, std, index)
      data = item_page_data(item, parent, std, index)
      page = Jekyll::PageWithoutAFile.new(@site, @site.source, '', "#{data['page_path']}/index.html")
      page.data = data
      page.content = ''
      @site.pages << page
    end

    def create_standard_index_page(std, classes)
      req_classes = classes.select { |k| k.is_a?(Modspec::NormativeStatementsClass) }.map do |k|
        { 'identifier' => k.identifier.to_s, 'name' => k.name }
      end

      conf_classes = classes.select { |k| k.is_a?(Modspec::ConformanceClass) }.map do |k|
        { 'identifier' => k.identifier.to_s, 'name' => k.name }
      end

      data = {
        'layout' => 'standard_index',
        'title' => std.meta_title,
        'standard_number' => std.number,
        'page_path' => std.number.to_s,
        'description' => std.meta_description,
        'uri_base' => std.uri_base,
        'req_classes' => req_classes,
        'conf_classes' => conf_classes
      }
      data['iso_standard_url'] = std.iso_standard_url if std.iso_standard_url
      data['iso_preview_url'] = std.iso_preview_url if std.iso_preview_url

      page = Jekyll::PageWithoutAFile.new(@site, @site.source, '', "#{std.number}/index.html")
      page.data = data
      page.content = ''
      @site.pages << page
    end

    private

    def class_page_data(klass, std, index)
      ident = klass.identifier.to_s
      is_req = klass.is_a?(Modspec::NormativeStatementsClass)

      render_data = ModelSerializer.serialize(klass)
      std.field_policy.strip_from!(render_data)

      data = {
        'layout' => 'provision_class',
        'title' => klass.name,
        'page_type' => is_req ? 'requirements_class' : 'conformance_class',
        'identifier' => ident,
        'uri_base' => std.uri_base,
        'standard_title' => std.meta_title,
        'page_path' => "#{std.uri_base}#{ident}",
        'data' => render_data,
        'xrefs' => build_class_xrefs(klass, index)
      }
      data['iso_standard_url'] = std.iso_standard_url if std.iso_standard_url
      data['iso_preview_url'] = std.iso_preview_url if std.iso_preview_url
      data
    end

    def item_page_data(item, parent, std, index)
      ident = item.identifier.to_s
      parent_ident = parent.identifier.to_s
      is_req = item.is_a?(Modspec::NormativeStatement)

      render_data = ModelSerializer.serialize(item)
      std.field_policy.strip_from!(render_data)

      data = {
        'layout' => 'provision_class',
        'title' => item.name,
        'page_type' => is_req ? 'requirement' : 'test',
        'identifier' => ident,
        'uri_base' => std.uri_base,
        'parent_identifier' => parent_ident,
        'parent_title' => parent.name,
        'standard_title' => std.meta_title,
        'page_path' => "#{std.uri_base}#{ident}",
        'data' => render_data,
        'xrefs' => build_item_xrefs(item, parent, index)
      }
      data['iso_standard_url'] = std.iso_standard_url if std.iso_standard_url
      data['iso_preview_url'] = std.iso_preview_url if std.iso_preview_url
      data
    end

    def build_class_xrefs(klass, index)
      xrefs = {}
      is_req = klass.is_a?(Modspec::NormativeStatementsClass)

      if is_req
        xrefs['tested_by'] = index.tested_by_conf_classes(klass.identifier.to_s)
      else
        target = klass.target.to_s
        xrefs['requirements_class'] = target unless target.empty?
      end

      deps = Array(klass.dependencies).map(&:to_s).reject(&:empty?)
      xrefs['dependencies'] = index.classify_deps(deps) unless deps.empty?

      xrefs
    end

    def build_item_xrefs(item, parent, index)
      xrefs = {}

      if item.is_a?(Modspec::NormativeStatement)
        test_ids = index.tested_by_tests(item.identifier.to_s)
        xrefs['tested_by'] = test_ids.map { |tid| { 'id' => tid, 'kind' => 'test' } }
      elsif item.is_a?(Modspec::ConformanceTest)
        targets = Array(item.targets).map(&:to_s).reject(&:empty?)
        xrefs['targets'] = targets.map { |t| { 'id' => t, 'kind' => index.dep_type(t) } }
      end

      xrefs
    end
  end
end
