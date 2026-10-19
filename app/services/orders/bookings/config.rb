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

  setting :drugstore_ids, default: [], constructor: IDS, reader: true

  def allowed?(drugstore_id) = drugstore_ids.include?(drugstore_id)
end
