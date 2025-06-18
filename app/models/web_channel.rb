class WebChannel < ApplicationRecord
  has_many :shows, dependent: :destroy
  has_many :episodes, through: :shows
  has_many :releases, through: :episodes

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :external_id, presence: true, uniqueness: true

  before_save :normalize_name

  private

  def normalize_name
    self.name = name.strip.titleize if name.present?
  end
end
