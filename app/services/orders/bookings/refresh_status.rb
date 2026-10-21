# frozen_string_literal: true

# Asks the provider for the status of a sent order and keeps it as the partner wrote it, with the time it was asked. A
# provider that does not answer leaves the kept status as it was; the failure is given back for the caller to decide.
class Orders::Bookings::RefreshStatus
  def self.call(order) = new(order).call

  # A sent order whose status is older than the configured minutes, or was never asked.
  def self.stale?(order, config: Orders::Bookings.config)
    synced_at = order.status_synced_at
    order.submitted? && (synced_at.nil? || synced_at < config.status_stale_minutes.minutes.ago)
  end

  def initialize(order)
    @order = order
  end

  def call
    adapter = Orders::Bookings::Adapters.for(@order.provider)
    answer = adapter ? adapter.status(@order) : Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil)
    return answer if answer.is_a?(Orders::Bookings::Failure)

    @order.update!(
      status_name: answer.status_name,
      status_comment: answer.status_comment,
      cancel_reason: answer.cancel_reason,
      progress: answer.progress,
      provider_updated_at: answer.updated_at,
      status_synced_at: Time.current
    )
    @order
  end
end
