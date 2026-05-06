# frozen_string_literal: true

module StandardsGenerator
  class SiteScanner
    def initialize(site)
      @site = site
    end

    def each_standard
      return enum_for(:each_standard) unless block_given?

      data_dir = File.join(@site.source, '_data')
      return unless File.directory?(data_dir)

      Dir.glob(File.join(data_dir, '*')).each do |std_dir|
        next unless File.directory?(std_dir)
        number = File.basename(std_dir)

        Dir.glob(File.join(std_dir, '*')).each do |part_dir|
          next unless File.directory?(part_dir)
          part = File.basename(part_dir)

          Dir.glob(File.join(part_dir, '*')).each do |edition_dir|
            next unless File.directory?(edition_dir)
            edition = File.basename(edition_dir)

            yield Standard.new(number: number, part: part, edition: edition, data_dir: edition_dir)
          end
        end
      end
    end
  end
end
