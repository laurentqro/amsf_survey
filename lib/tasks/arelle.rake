# frozen_string_literal: true

namespace :arelle do
  desc "Sync taxonomy files to arelle_api cache"
  task :sync do
    require "fileutils"
    require "yaml"
    require "uri"

    arelle_cache = ENV.fetch("ARELLE_CACHE_PATH") do
      File.expand_path("../../../arelle_api/cache", __dir__)
    end

    # Find all plugin gems
    plugin_dirs = Dir.glob(File.join(__dir__, "../../amsf_survey-*/"))

    plugin_dirs.each do |plugin_dir|
      plugin_name = File.basename(plugin_dir)
      taxonomy_base = File.join(plugin_dir, "taxonomies")

      next unless File.directory?(taxonomy_base)

      # Process each year
      Dir.children(taxonomy_base).each do |year|
        year_path = File.join(taxonomy_base, year)
        next unless File.directory?(year_path)

        config_path = File.join(year_path, "taxonomy.yml")
        next unless File.exist?(config_path)

        config = YAML.safe_load(File.read(config_path), symbolize_names: true)
        schema_url = config[:schema_url]
        next unless schema_url

        # Parse URL to determine cache path
        uri = URI.parse(schema_url)
        cache_dir = File.join(arelle_cache, uri.scheme, uri.host, File.dirname(uri.path))

        puts "Syncing #{plugin_name}/#{year} -> #{cache_dir}"

        # Create cache directory
        FileUtils.mkdir_p(cache_dir)

        # Copy taxonomy files (xsd, xml, but not yml)
        Dir.glob(File.join(year_path, "*.{xsd,xml}")).each do |file|
          dest = File.join(cache_dir, File.basename(file))
          FileUtils.cp(file, dest)
          puts "  Copied #{File.basename(file)}"
        end

        # Create entry point XSD if different from main schema
        entry_xsd = File.basename(uri.path)
        main_xsd = Dir.glob(File.join(cache_dir, "*.xsd")).first
        if main_xsd && File.basename(main_xsd) != entry_xsd
          entry_path = File.join(cache_dir, entry_xsd)
          unless File.exist?(entry_path)
            FileUtils.cp(main_xsd, entry_path)
            puts "  Created entry point #{entry_xsd}"
          end
        end
      end
    end

    puts "Sync complete!"
  end
end
