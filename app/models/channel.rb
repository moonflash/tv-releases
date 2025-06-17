class Channel < ApplicationRecord
  has_many :releases, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  before_save :normalize_name

  # Find or create a channel with fuzzy name matching
  def self.find_or_create_by_fuzzy_name(channel_name)
    return nil if channel_name.blank?

    normalized_name = normalize_channel_name(channel_name)

    # First try exact match (case insensitive)
    channel = find_by("LOWER(name) = ?", normalized_name.downcase)
    return channel if channel

    # Try fuzzy matching for similar names
    existing_channels = all.select do |ch|
      similarity_score(ch.name.downcase, normalized_name.downcase) > 0.8
    end

    return existing_channels.first if existing_channels.any?

    # Create new channel
    create!(name: normalized_name)
  end

  private

  def normalize_name
    self.name = self.class.normalize_channel_name(name)
  end

  def self.normalize_channel_name(name)
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
