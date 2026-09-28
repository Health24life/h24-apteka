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
