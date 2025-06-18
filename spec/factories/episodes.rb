FactoryBot.define do
  factory :episode do
    sequence(:season_number) { |n| n }
    sequence(:episode_number) { |n| n }
    sequence(:external_id) { |n| "ep_#{n}" }
    association :show
  end
end 