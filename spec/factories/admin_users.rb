# frozen_string_literal: true

FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }
    is_active { true }

    trait :inactive do
      is_active { false }
    end
  end
end
