FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "Country#{n}" }
    sequence(:shortcode) { |n| "C#{n}" }
  end
end
