namespace :releases do
  desc "Import upcoming TV releases from TVMaze"
  task import: :environment do
    puts "Starting TV releases import..."

    begin
      result = ReleaseImportService.import_upcoming_releases

      puts "Import completed successfully!"
      puts "  - Imported: #{result[:imported]} new releases"
      puts "  - Skipped: #{result[:skipped]} duplicates"
      puts "  - Errors: #{result[:errors]} errors"

      if result[:errors] > 0
        puts "Check the logs for error details."
        exit 1
      end

    rescue => e
      puts "Fatal error during import: #{e.message}"
      Rails.logger.error "[ReleaseImportTask] Fatal error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      exit 1
    end
  end

  desc "Clean up old releases (older than 7 days)"
  task cleanup: :environment do
    puts "Cleaning up old releases..."

    begin
      cutoff_date = Date.current - 7.days
      deleted_count = Release.where("air_date < ?", cutoff_date).delete_all

      puts "Deleted #{deleted_count} old releases (older than #{cutoff_date})"
      Rails.logger.info "[ReleaseCleanupTask] Deleted #{deleted_count} old releases"

    rescue => e
      puts "Error during cleanup: #{e.message}"
      Rails.logger.error "[ReleaseCleanupTask] Error: #{e.message}"
      exit 1
    end
  end

  desc "Full maintenance: import new releases and cleanup old ones"
  task maintain: :environment do
    puts "Running full releases maintenance..."

    Rake::Task["releases:import"].invoke
    Rake::Task["releases:cleanup"].invoke

    puts "Maintenance completed!"
  end
end
