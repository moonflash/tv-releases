class ExtractEpisodeDataJob < ApplicationJob
  queue_as :default

  def perform(episode_id)
    episode = Episode.find_by(external_id: episode_id)
    return unless episode

    episode_data = Crawl4aiService.extract_episode(episode_id)
    return if episode_data.blank?

    episode.update!(
      season_number: episode_data["season"],
      episode_number: episode_data["episode"],
      airdate: episode_data["airdate"],
      runtime: episode_data["runtime"],
      summary: episode_data["summary"]
    )
  rescue => e
    Rails.logger.error "[ExtractEpisodeDataJob] Error extracting episode data for episode_id #{episode_id}: #{e.message}"
  end
end 