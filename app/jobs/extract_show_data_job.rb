class ExtractShowDataJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 5

  def perform(show_id)
    show = Show.find_by(external_id: show_id)
    return unless show

    show_data = Crawl4aiService.extract_show(show_id)
    return if show_data.blank?

    show.update!(
      title: show_data["title"],
      description: show_data["description"],
      show_type: show_data["show_type"],
      official_site_url: show_data["official_site_url"],
      genres: show_data["genres"],
      vote: show_data["vote"]
    )
  rescue => e
    if executions < MAX_RETRIES
      Rails.logger.warn "[ExtractShowDataJob] Attempt #{executions} failed for show_id #{show_id}: #{e.message}. Retrying (#{executions}/#{MAX_RETRIES})"
      retry_job wait: 30.seconds
    else
      Rails.logger.error "[ExtractShowDataJob] Error extracting show data for show_id #{show_id}: #{e.message} (failed after #{MAX_RETRIES} attempts)"
    end
  end
end
