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

    network = nil
    web_channel = nil

    if release_data["network_id"].present?
      network = Network.find_or_create_by(external_id: release_data["network_id"]) do |n|
        n.name = "Network #{release_data['network_id']}"
      end
    elsif release_data["web_channel_id"].present?
      web_channel = WebChannel.find_or_create_by(external_id: release_data["web_channel_id"]) do |w|
        w.name = "WebChannel #{release_data['web_channel_id']}"
      end
    else
      Rails.logger.warn "[Release] No network_id or web_channel_id provided in crawl data: #{release_data.inspect}"
      return nil
    end

    # Find or create show with minimal data
    show = Show.find_or_create_from_external_id(release_data["show_id"], network: network, web_channel: web_channel)
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
    episode.show.network || episode.show.web_channel
  end

  def country
    episode.show.network&.country
  end

  def title
    show.title
  end

  def episode_title
    "#{episode.title} - #{show.title}"
  end
end
