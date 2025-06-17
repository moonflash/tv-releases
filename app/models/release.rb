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

    # Find or create show with minimal data
    show = Show.find_or_create_by(external_id: release_data["show_id"]) do |s|
      s.network = network
    end
    return nil unless show

    # Enqueue show data extraction if show is new or incomplete
    ExtractShowDataJob.perform_later(release_data["show_id"]) if show.title.blank?

    # Find or create episode with minimal data
    episode = Episode.find_or_create_by(external_id: release_data["episode_id"]) do |e|
      e.show = show
      e.season_number = 0  # Temporary value
      e.episode_number = 0 # Temporary value
    end
    return nil unless episode

    # Enqueue episode data extraction if episode is new or incomplete
    ExtractEpisodeDataJob.perform_later(release_data["episode_id"]) if episode.season_number.zero?

    # Check if release already exists
    existing = find_by(
      air_date: air_date,
      air_time: air_time,
      episode: episode
    )

    if existing
      return :skipped
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
