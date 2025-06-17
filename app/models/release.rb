class Release < ApplicationRecord
  belongs_to :episode

  validates :air_date, :air_time, presence: true
  validates :air_date, :air_time, uniqueness: { scope: :episode_id }

  scope :upcoming, -> { where("air_date >= ?", Date.current) }
  scope :within_days, ->(days) { where("air_date >= ? AND air_date <= ?", Date.current, Date.current + days.days) }

  def self.find_or_create_from_crawl_data(release_data)
    # Parse date and time from the crawl data
    air_date = Date.parse(release_data["date"])
    air_time = Time.parse(release_data["time"]).strftime("%H:%M:%S")

    # Find or create network
    network = Network.find_or_create_by_fuzzy_name_and_external_id(
      release_data["network_name"], 
      release_data["network_id"],
      nil # We'll handle country separately if needed
    )
    return nil unless network

    # Find or create show
    show = Show.find_or_create_from_external_id(release_data["show_id"], network)
    return nil unless show

    # Find or create episode
    episode = Episode.find_or_create_from_external_id(release_data["episode_id"], show)
    return nil unless episode

    # Check if release already exists
    existing = find_by(
      air_date: air_date,
      air_time: air_time,
      episode: episode
    )

    if existing
      return existing
    end

    # Create new release
    create!(
      air_date: air_date,
      air_time: air_time,
      episode: episode
    )
  end

  # Delegated methods for easier access
  def show
    episode.show
  end

  def network
    episode.show.network
  end

  def country
    episode.show.network.country
  end

  def title
    show.title
  end

  def episode_title
    "#{episode.title} - #{show.title}"
  end
end
