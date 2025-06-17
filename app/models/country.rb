class Country < ApplicationRecord
  has_many :releases, dependent: :nullify

  validates :name, presence: true
  validates :shortcode, presence: true, uniqueness: true

  def self.find_or_create_by_shortcode(shortcode, name = nil)
    return nil if shortcode.blank?

    # Normalize shortcode to uppercase
    shortcode = shortcode.upcase

    # Try to find existing country
    country = find_by(shortcode: shortcode)
    return country if country

    # Create new country if it doesn't exist
    country_name = name.present? ? name : shortcode
    create!(shortcode: shortcode, name: country_name)
  rescue ActiveRecord::RecordInvalid => e
    # In case of race condition, try to find again
    find_by(shortcode: shortcode)
  end
end
