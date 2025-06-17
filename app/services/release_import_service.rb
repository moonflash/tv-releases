class ReleaseImportService
  include HTTParty

  BASE_URL = "https://www.tvmaze.com/countdown"
  MAX_DAYS_AHEAD = 90
  MAX_RETRIES = 5
  BASE_RETRY_DELAY = 30 # seconds

  def self.import_upcoming_releases
    new.import_upcoming_releases
  end

  def initialize
    @imported_count = 0
    @skipped_count = 0
    @error_count = 0
    @cutoff_date = Date.current + MAX_DAYS_AHEAD.days
  end

  def import_upcoming_releases
    Rails.logger.info "[ReleaseImportService] Starting import of upcoming releases"

    page = 1
    loop do
            Rails.logger.info "[ReleaseImportService] Processing page #{page}"

      url = "#{BASE_URL}?page=#{page}"
      releases_data = extract_with_retry(url)

      if releases_data.empty?
        Rails.logger.info "[ReleaseImportService] No data returned for page #{page}, stopping"
        break
      end

      # Check if we've gone beyond our cutoff date
      break if beyond_cutoff_date?(releases_data)

      process_releases(releases_data)

      page += 1

      # Safety break to prevent infinite loops
      break if page > 50
    end

    log_summary

    {
      imported: @imported_count,
      skipped: @skipped_count,
      errors: @error_count
    }
  end

    private

  def extract_with_retry(url)
    retries = 0

    loop do
      Rails.logger.info "[ReleaseImportService] Calling Crawl4aiService for #{url} (attempt #{retries + 1}/#{MAX_RETRIES + 1})"

      releases_data = Crawl4aiService.extract(url)

      # If we got releases or we've exhausted retries, return the data
      if !releases_data.empty? || retries >= MAX_RETRIES
        if releases_data.empty? && retries >= MAX_RETRIES
          Rails.logger.warn "[ReleaseImportService] No releases found after #{MAX_RETRIES + 1} attempts for #{url}"
        elsif !releases_data.empty?
          Rails.logger.info "[ReleaseImportService] Successfully retrieved #{releases_data.size} releases from #{url}"
        end
        return releases_data
      end

      # Calculate delay: 30s, 60s, 90s, 120s, 150s
      delay = BASE_RETRY_DELAY * (retries + 1)
      Rails.logger.warn "[ReleaseImportService] No releases found for #{url}, retrying in #{delay} seconds (attempt #{retries + 1}/#{MAX_RETRIES + 1})"

      sleep(delay)
      retries += 1
    end
  end

  def process_releases(releases_data)
    releases_data.each do |release_data|
      begin
        # Skip if release is beyond our cutoff date
        next if release_beyond_cutoff?(release_data)

        # Find or create channel
        channel = find_or_create_channel(release_data["channel"])

        # Find or create release
        existing_release = Release.find_by(
          title: release_data["title"],
          air_date: Date.parse(release_data["date"]),
          air_time: Time.parse(release_data["time"]).strftime("%H:%M:%S"),
          season_number: release_data.dig("episode", "season"),
          episode_number: release_data.dig("episode", "number")
        )

        if existing_release
          @skipped_count += 1
          Rails.logger.debug "[ReleaseImportService] Skipped duplicate: #{existing_release.title} (#{existing_release.air_date})"
        else
          release = Release.find_or_create_from_crawl_data(release_data, channel)
          if release.persisted?
            @imported_count += 1
            Rails.logger.info "[ReleaseImportService] Imported: #{release.title} (#{release.air_date})"
          else
            @error_count += 1
            Rails.logger.error "[ReleaseImportService] Failed to save release: #{release.errors.full_messages.join(', ')}"
          end
        end

      rescue => e
        @error_count += 1
        Rails.logger.error "[ReleaseImportService] Error processing release: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end

  def find_or_create_channel(channel_name)
    return nil if channel_name.blank?

    Channel.find_or_create_by_fuzzy_name(channel_name)
  rescue => e
    Rails.logger.error "[ReleaseImportService] Error finding/creating channel '#{channel_name}': #{e.message}"
    nil
  end

  def beyond_cutoff_date?(releases_data)
    return false if releases_data.empty?

    # Check if all releases in this batch are beyond our cutoff
    releases_data.all? do |release_data|
      release_beyond_cutoff?(release_data)
    end
  end

  def release_beyond_cutoff?(release_data)
    return false unless release_data["date"]

    begin
      air_date = Date.parse(release_data["date"])
      air_date > @cutoff_date
    rescue Date::Error
      Rails.logger.warn "[ReleaseImportService] Invalid date format: #{release_data['date']}"
      false
    end
  end

  def log_summary
    Rails.logger.info "[ReleaseImportService] Import completed:"
    Rails.logger.info "  - Imported: #{@imported_count} releases"
    Rails.logger.info "  - Skipped: #{@skipped_count} duplicates"
    Rails.logger.info "  - Errors: #{@error_count} errors"
  end
end
