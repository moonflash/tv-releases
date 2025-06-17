class Release < ApplicationRecord
  belongs_to :channel, optional: true

  validates :air_date, :air_time, :title, :season_number, :episode_number, :episode_title, presence: true
  validates :title, uniqueness: {
    scope: [ :air_date, :air_time, :season_number, :episode_number ],
    message: "Release already exists with same title, air date, time, season and episode number"
  }

  scope :upcoming, -> { where("air_date >= ?", Date.current) }
  scope :within_days, ->(days) { where("air_date <= ?", Date.current + days.days) }

  def self.find_or_create_from_crawl_data(data, channel)
    # Parse date and time from the crawl data
    air_date = Date.parse(data["date"])
    air_time = Time.parse(data["time"]).strftime("%H:%M:%S")

    # Check if release already exists
    existing = find_by(
      title: data["title"],
      air_date: air_date,
      air_time: air_time,
      season_number: data.dig("episode", "season"),
      episode_number: data.dig("episode", "number")
    )

    return existing if existing

    # Create new release
    create!(
      title: data["title"],
      air_date: air_date,
      air_time: air_time,
      season_number: data.dig("episode", "season"),
      episode_number: data.dig("episode", "number"),
      episode_title: data.dig("episode", "title"),
      channel: channel
    )
  end
end
