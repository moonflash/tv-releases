class Release < ApplicationRecord
  belongs_to :channel, optional: true
  belongs_to :country, optional: true

  validates :air_date, :air_time, :title, :season_number, :episode_number, :episode_title, presence: true
  validates :title, uniqueness: {
    scope: [ :air_date, :air_time, :season_number, :episode_number ],
    message: "Release already exists with same title, air date, time, season and episode number"
  }
  validates :external_id, uniqueness: true, allow_blank: true

  scope :upcoming, -> { where("air_date >= ?", Date.current) }
  scope :within_days, ->(days) { where("air_date >= ? AND air_date <= ?", Date.current, Date.current + days.days) }

  def self.find_or_create_from_crawl_data(data, channel)
    # Parse date and time from the crawl data
    air_date = Date.parse(data["date"])
    air_time = Time.parse(data["time"]).strftime("%H:%M:%S")

    # Find or create country if country_code is provided
    country = nil
    if data["country_code"].present?
      country = Country.find_or_create_by_shortcode(data["country_code"], data["country"])
    end

    # Check if release already exists by external_id first
    if data["external_id"].present?
      existing = find_by(external_id: data["external_id"])
      if existing
        # Update existing release with new data
        existing.update!(
          title: data["title"],
          air_date: air_date,
          air_time: air_time,
          season_number: data.dig("episode", "season"),
          episode_number: data.dig("episode", "number"),
          episode_title: data.dig("episode", "title"),
          url: data["url"],
          channel: channel,
          country: country
        )
        return existing
      end
    end

    # Check if release already exists by other fields
    existing = find_by(
      title: data["title"],
      air_date: air_date,
      air_time: air_time,
      season_number: data.dig("episode", "season"),
      episode_number: data.dig("episode", "number")
    )

    if existing
      # Update existing release with new data
      existing.update!(
        episode_title: data.dig("episode", "title"),
        url: data["url"],
        external_id: data["external_id"],
        channel: channel,
        country: country
      )
      return existing
    end

    # Create new release
    create!(
      title: data["title"],
      air_date: air_date,
      air_time: air_time,
      season_number: data.dig("episode", "season"),
      episode_number: data.dig("episode", "number"),
      episode_title: data.dig("episode", "title"),
      url: data["url"],
      external_id: data["external_id"],
      channel: channel,
      country: country
    )
  end
end
