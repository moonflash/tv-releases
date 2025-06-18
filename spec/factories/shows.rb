FactoryBot.define do
  factory :show do
    sequence(:title) { |n| "Show#{n}" }
    sequence(:external_id) { |n| "show_#{n}" }
    association :network
  end
end 