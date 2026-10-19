# frozen_string_literal: true

# Asks the provider for the status of one sent order. A short lock of the row keeps two runs from writing over each
# other; a refusal for the limit puts the job off for the wait the provider asked.
class Orders::Bookings::StatusRefreshWorker < ApplicationWorker
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(order_id)
    order = Order.submitted.find_by(id: order_id)
    return unless order

    answer = order.with_lock { Orders::Bookings::RefreshStatus.call(order) }
    return unless answer.is_a?(Orders::Bookings::Failure) && answer.rate_limited?

      self.class.perform_in(
        answer.retry_after,
        order_id
      )
  end
end
