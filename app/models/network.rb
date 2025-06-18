class Network < ApplicationRecord
  belongs_to :country, optional: true
  has_many :shows, dependent: :destroy
  has_many :episodes, through: :shows
  has_many :releases, through: :episodes

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :external_id, presence: true, uniqueness: true

  before_save :normalize_name

  # Find or create a network with fuzzy name matching
  def self.find_or_create_by_fuzzy_name_and_external_id(network_name, external_id, country = nil)
    return nil if network_name.blank? || external_id.blank?

    # First try to find by external_id
    network = find_by(external_id: external_id)
    return network if network

    normalized_name = normalize_network_name(network_name)

    # Try exact match (case insensitive)
    network = find_by("LOWER(name) = ?", normalized_name.downcase)
    if network
      network.update!(external_id: external_id) if network.external_id != external_id
      return network
    end

    # Try fuzzy matching for similar names
    existing_networks = all.select do |net|
      similarity_score(net.name.downcase, normalized_name.downcase) > 0.8
    end

    if existing_networks.any?
      network = existing_networks.first
      network.update!(external_id: external_id) if network.external_id != external_id
      return network
    end

    # Create new network
    create!(
      name: normalized_name,
      external_id: external_id,
      country: country
    )
  end

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

  # Calculate similarity between two strings using Levenshtein distance
  def self.similarity_score(str1, str2)
    return 1.0 if str1 == str2
    return 0.0 if str1.empty? || str2.empty?

    distance = levenshtein_distance(str1, str2)
    max_length = [ str1.length, str2.length ].max

    1.0 - (distance.to_f / max_length)
  end

  def self.levenshtein_distance(str1, str2)
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      # deletion
          matrix[i][j - 1] + 1,      # insertion
          matrix[i - 1][j - 1] + cost # substitution
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end
end
