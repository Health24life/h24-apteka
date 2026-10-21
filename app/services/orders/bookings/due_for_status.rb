# frozen_string_literal: true

# The sent orders whose status is still asked about: not final yet, and booked within the configured days.
module Orders::Bookings::DueForStatus
  def self.call(config: Orders::Bookings.config, now: Time.current)
    recent = Order.submitted.where(personal_data_consent_at: (now - config.status_poll_days.days)..)
    recent.where(status_name: nil).or(recent.where.not(status_name: config.final_statuses))
  end
end
