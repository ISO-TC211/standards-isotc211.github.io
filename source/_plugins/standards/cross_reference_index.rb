# frozen_string_literal: true

module StandardsGenerator
  class CrossReferenceIndex
    def initialize
      @all_ids = {}
      @conf_targets_rc = {}
      @req_tested_by = {}
    end

    def register_rc(rc)
      id = rc.identifier.to_s
      @all_ids[id] = :req_class
      Array(rc.normative_statements).each do |ns|
        @all_ids[ns.identifier.to_s] = :requirement
      end
    end

    def register_cc(cc)
      id = cc.identifier.to_s
      @all_ids[id] = :conf_class

      target = cc.target.to_s
      unless target.empty?
        @conf_targets_rc[target] ||= []
        @conf_targets_rc[target] << id
      end

      Array(cc.tests).each do |test|
        test_id = test.identifier.to_s
        @all_ids[test_id] = :conf_test

        Array(test.targets).each do |t|
          tid = t.to_s
          @req_tested_by[tid] ||= []
          @req_tested_by[tid] << test_id
        end
      end
    end

    def tested_by_conf_classes(rc_id)
      @conf_targets_rc[rc_id.to_s] || []
    end

    def tested_by_tests(req_id)
      @req_tested_by[req_id.to_s] || []
    end

    def dep_type(dep_id)
      case @all_ids[dep_id.to_s]
      when :req_class then 'req_class'
      when :conf_class then 'conf_class'
      when :requirement then 'requirement'
      when :conf_test then 'conf_test'
      else
        dep_id.include?('/conf/') ? 'conf_test' : 'requirement'
      end
    end

    def classify_deps(deps)
      Array(deps).reject { |d| d.nil? || d.to_s.empty? }.map do |dep|
        { 'id' => dep.to_s, 'kind' => dep_type(dep) }
      end
    end
  end
end
