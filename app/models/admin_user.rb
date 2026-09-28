# frozen_string_literal: true

class AdminUser < ApplicationRecord
  devise :database_authenticatable, :rememberable, :validatable

  def self.ransackable_attributes(_auth_object = nil)
    super - %w[encrypted_password]
  end

  # Devise's activatable Warden hook calls this after EVERY authenticated request, so clearing
  # is_active signs the account out at once rather than at its next sign-in.
  def active_for_authentication?
    super && is_active?
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
