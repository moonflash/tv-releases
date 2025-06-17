class ExtractShowDataJob < ApplicationJob
  queue_as :default

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
    Rails.logger.error "[ExtractShowDataJob] Error extracting show data for show_id #{show_id}: #{e.message}"
  end
end 