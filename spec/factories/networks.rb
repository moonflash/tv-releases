FactoryBot.define do
  factory :network do
    sequence(:name) { |n| "Network#{n}" }
    sequence(:external_id) { |n| "net_#{n}" }
    association :country
  end
end 