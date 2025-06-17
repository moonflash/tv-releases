class Episode < ApplicationRecord
  belongs_to :show
  has_many :releases, dependent: :destroy

  validates :season_number, :episode_number, presence: true
  validates :external_id, presence: true, uniqueness: true
  validates :season_number, :episode_number, uniqueness: { scope: :show_id }

  def self.find_or_create_from_external_id(external_id, show)
    return nil if external_id.blank?

    # Try to find existing episode
    episode = find_by(external_id: external_id)
    return episode if episode

    # Extract episode data from external source
    episode_data = Crawl4aiService.extract_episode(external_id)
    return nil if episode_data.blank? || episode_data["season"].blank? || episode_data["episode"].blank?

    # Create new episode
    create!(
      external_id: external_id,
      season_number: episode_data["season"],
      episode_number: episode_data["episode"],
      airdate: episode_data["airdate"],
      runtime: episode_data["runtime"],
      summary: episode_data["summary"],
      show: show
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Episode] Error creating episode #{external_id}: #{e.message}"
    # In case of race condition, try to find again
    find_by(external_id: external_id)
  rescue => e
    Rails.logger.error "[Episode] Exception creating episode #{external_id}: #{e.message}"
    nil
  end

  def title
    "S#{season_number.to_s.rjust(2, '0')}E#{episode_number.to_s.rjust(2, '0')}"
  end
end 