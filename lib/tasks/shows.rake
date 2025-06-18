namespace :shows do
  desc "Synchronize all shows via Crawl4aiService and update their data"
  task sync: :environment do
    puts "[shows:sync] Starting synchronization of shows..."

    stats = ShowSyncService.sync_all

    puts "[shows:sync] Completed."
    puts "  Updated: #{stats[:updated]}"
    puts "  Skipped: #{stats[:skipped]} (no data returned)"
    puts "  Errors:  #{stats[:errors]}"
  end
end
