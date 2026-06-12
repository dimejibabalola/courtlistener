FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    full_name { "Test User" }
    ai_provider { "local" }
  end

  factory :organization do
    sequence(:name) { |n| "Firm #{n} LLP" }
  end
end
