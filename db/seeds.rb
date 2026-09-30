# frozen_string_literal: true

if Rails.env.development?
  AdminUser.find_or_create_by!(email: "admin@example.com") do |admin|
    admin.password = admin.password_confirmation = "password"
  end
end

# Only the identity of the provider is seeded; flags edited later in the admin panel must survive a re-seed.
Provider.create_with(name: 'Pharmapoint', kind: 'external', supports_e_recipe: true, supports_delivery: false)
        .find_or_create_by!(code: 'pharmapoint')
