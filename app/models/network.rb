class Network < ApplicationRecord
  belongs_to :country, optional: true
  has_many :shows, dependent: :destroy
  has_many :episodes, through: :shows
  has_many :releases, through: :episodes

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :external_id, presence: true, uniqueness: true

  before_save :normalize_name

  private

  def normalize_name
    self.name = self.class.normalize_network_name(name)
  end

  def self.normalize_network_name(name)
    return "" if name.blank?

    # Remove common TV network suffixes/prefixes and normalize
    normalized = name.strip
                     .gsub(/\b(TV|Network|Channel|Broadcasting)\b/i, "")
                     .gsub(/\s+/, " ")
                     .strip
                     .titleize

    # Handle special cases
    case normalized.downcase
    when /\bhbo\b/
      "HBO"
    when /\bcnn\b/
      "CNN"
    when /\bbbc\b/
      "BBC"
    when /\babc\b/
      "ABC"
    when /\bcbs\b/
      "CBS"
    when /\bnbc\b/
      "NBC"
    when /\bfox\b/
      "FOX"
    else
      normalized
    end
  end
end
