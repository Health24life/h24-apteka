# frozen_string_literal: true

if Rails.env.development?
  AdminUser.find_or_create_by!(email: "admin@example.com") do |admin|
    admin.password = admin.password_confirmation = "password"
  end
end
