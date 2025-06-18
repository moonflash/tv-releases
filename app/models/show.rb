class Show < ApplicationRecord
  belongs_to :network
  has_many :episodes, dependent: :destroy
  has_many :releases, through: :episodes

  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true, on: :update

  def self.find_or_create_from_external_id(external_id, network)
    return nil if external_id.blank?

    find_or_create_by(external_id: external_id) do |show|
      show.network = network
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Show] Error creating show #{external_id}: #{e.message}"
    # In case of race condition, try to find again
    find_by(external_id: external_id)
  rescue => e
    Rails.logger.error "[Show] Exception creating show #{external_id}: #{e.message}"
    nil
  end
end 