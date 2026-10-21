# frozen_string_literal: true

# Settings of booking. The values come from the environment in config/initializers/settings.rb, which keeps the frozen
# result as Orders::Bookings.config.
class Orders::Bookings::Config
  include Dry::Configurable

  # Ids of the drugstores of the directory booking is allowed in, comma-separated in the environment; none turns it off.
  IDS = lambda do |value|
    entries = value.is_a?(String) ? value.split(',') : Array(value)
    entries.filter_map { |entry| Integer(entry.to_s.strip, exception: false) }
  end

  INTEGER = ->(value) { Integer(value) }
  # Statuses of the partner after which an order is not asked about any more, comma-separated in the environment.
  STATUSES = lambda do |value|
    entries = value.is_a?(String) ? value.split(',') : Array(value)
    entries.map { |entry| entry.to_s.strip }.compact_blank
  end

  setting :drugstore_ids, default: [], constructor: IDS, reader: true
  # An order shown with a status older than this, in minutes, asks the partner for it first.
  setting :status_stale_minutes, default: 5, constructor: INTEGER, reader: true
  # Days after booking an order is still asked about, when its status is not final yet.
  setting :status_poll_days, default: 3, constructor: INTEGER, reader: true
  setting :final_statuses, default: %w[canceled], constructor: STATUSES, reader: true
  # Orders on a page of the history, and the most a page may ask for.
  setting :history_per_page, default: 20, constructor: INTEGER, reader: true
  setting :history_max_per_page, default: 50, constructor: INTEGER, reader: true

  def allowed?(drugstore_id) = drugstore_ids.include?(drugstore_id)

  def final?(status_name) = final_statuses.include?(status_name)
end
