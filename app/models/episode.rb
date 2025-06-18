class Episode < ApplicationRecord
  belongs_to :show
  has_many :releases, dependent: :destroy

  validates :external_id, presence: true, uniqueness: true
  validates :season_number, :episode_number, presence: true, on: :update
  validates :season_number, :episode_number, uniqueness: { scope: :show_id }, on: :update

  def self.find_or_create_from_external_id(external_id, show)
    return nil if external_id.blank?

    find_or_create_by(external_id: external_id) do |episode|
      episode.show = show
      episode.season_number = 0  # Temporary value
      episode.episode_number = 0 # Temporary value
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Episode] Error creating episode #{external_id}: #{e.message}"
    # In case of race condition, try to find again
    find_by(external_id: external_id)
  rescue => e
    Rails.logger.error "[Episode] Exception creating episode #{external_id}: #{e.message}"
    nil
  end

  def title
    return "TBD" if season_number.zero? || episode_number.zero?
    "S#{season_number.to_s.rjust(2, '0')}E#{episode_number.to_s.rjust(2, '0')}"
  end
end 