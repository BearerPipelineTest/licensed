# frozen_string_literal: true
module Licensed
  module Commands
    class Cache < Command
      def initialize(config:, reporter: Licensed::Reporters::CacheReporter.new)
        super(config: config, reporter: reporter)
      end

      protected

      # Run the command for all enumerated dependencies found in a dependency source,
      # recording results in a report.
      # Removes any cached records that don't match a current application
      # dependency.
      #
      # app - The application configuration for the source
      # source - A dependency source enumerator
      #
      # Returns whether the command succeeded for the dependency source enumerator
      def run_source(app, source)
        result = super
        clear_stale_cached_records(app, source) if result
        result
      end

      # Cache dependency record data.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns true.
      def evaluate_dependency(app, source, dependency, report)
        filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
        cached_record = Licensed::DependencyRecord.read(filename)
        if options[:force] || save_dependency_record?(dependency, cached_record)
          # use the cached license value if the license text wasn't updated
          dependency.record["license"] = cached_record["license"] if dependency.record.matches?(cached_record)
          dependency.record.save(filename)
          report["cached"] = true
        end

        true
      end

      # Determine if the current dependency's record should be saved.
      # The record should be saved if:
      # 1. there is no cached record
      # 2. the cached record doesn't have a version set
      # 3. the cached record version doesn't match the current dependency version
      #
      # dependency - An application dependency
      # cached_record - A dependency record to compare with the dependency
      #
      # Returns true if dependency's record should be saved
      def save_dependency_record?(dependency, cached_record)
        return true if cached_record.nil?

        cached_version = cached_record["version"]
        return true if cached_version.nil? || cached_version.empty?
        return true if dependency.version != cached_version
        false
      end

      # Clean up cached files that dont match current dependencies
      #
      # app - An application configuration
      # source - A dependency source enumerator
      #
      # Returns nothing
      def clear_stale_cached_records(app, source)
        names = source.dependencies.map { |dependency| File.join(source.class.type, dependency.name) }
        Dir.glob(app.cache_path.join(source.class.type, "**/*.#{DependencyRecord::EXTENSION}")).each do |file|
          file_path = Pathname.new(file)
          relative_path = file_path.relative_path_from(app.cache_path).to_s
          FileUtils.rm(file) unless names.include?(relative_path.chomp(".#{DependencyRecord::EXTENSION}"))
        end
      end
    end
  end
end
