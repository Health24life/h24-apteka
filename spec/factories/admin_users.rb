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

# == Schema Information
#
# Table name: admin_users
#
#  id                  :bigint           not null, primary key
#  email               :string           default(""), not null
#  encrypted_password  :string           default(""), not null
#  is_active           :boolean          default(TRUE), not null
#  remember_created_at :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_admin_users_on_email  (email) UNIQUE
#
