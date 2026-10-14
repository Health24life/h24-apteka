# frozen_string_literal: true

# The seed admin and two more, so the history has several authors to filter by. The password is the seed's.
module DevSamples::Admins
  EMAILS = %w[admin@example.com olena@example.com taras@example.com].freeze

  module_function

  def call
    EMAILS.map do |email|
      AdminUser.find_or_create_by!(email:) { it.password = it.password_confirmation = 'password' }
    end
  end
end
