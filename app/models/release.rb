class Release < ApplicationRecord
  validates :air_date, :air_time, :title, :season_number, :episode_number, :episode_title, presence: true
end 