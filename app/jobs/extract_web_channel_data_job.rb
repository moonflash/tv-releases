class ExtractWebChannelDataJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 5

  def perform(web_channel_id)
    web_channel = WebChannel.find_by(external_id: web_channel_id)
    return unless web_channel

    data = Crawl4aiService.extract_web_channel(web_channel_id)
    return if data.blank?

    web_channel.update!(
      name: data["name"].presence || web_channel.name,
      description: data["description"],
      time_zone: data["time_zone"],
      official_site_url: data["official_url"]
    )
  rescue => e
    if executions < MAX_RETRIES
      Rails.logger.warn "[ExtractWebChannelDataJob] Attempt #{executions} failed for web_channel_id #{web_channel_id}: #{e.message}. Retrying (#{executions}/#{MAX_RETRIES})"
      retry_job wait: 30.seconds
    else
      Rails.logger.error "[ExtractWebChannelDataJob] Error extracting web channel data for web_channel_id #{web_channel_id}: #{e.message} (failed after #{MAX_RETRIES} attempts)"
    end
  end
end
