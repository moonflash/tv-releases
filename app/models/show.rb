class Show < ApplicationRecord
  belongs_to :network
  has_many :episodes, dependent: :destroy
  has_many :releases, through: :episodes

  validates :title, presence: true
  validates :external_id, presence: true, uniqueness: true

  def self.find_or_create_from_external_id(external_id, network)
    return nil if external_id.blank?

    # Try to find existing show
    show = find_by(external_id: external_id)
    return show if show

    # Extract show data from external source
    show_data = Crawl4aiService.extract_show(external_id)
    return nil if show_data.blank? || show_data["title"].blank?

    # Create new show
    create!(
      external_id: external_id,
      title: show_data["title"],
      description: show_data["description"],
      show_type: show_data["show_type"],
      official_site_url: show_data["official_site_url"],
      genres: show_data["genres"]&.join(", "),
      vote: show_data["vote"],
      network: network
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Show] Error creating show #{external_id}: #{e.message}"
    # In case of race condition, try to find again
    find_by(external_id: external_id)
  rescue => e
    Rails.logger.error "[Show] Exception creating show #{external_id}: #{e.message}"
    nil
  end
end 