FactoryBot.define do
  factory :release do
    air_date { Date.today }
    air_time { '20:00' }
    association :episode
  end
end
