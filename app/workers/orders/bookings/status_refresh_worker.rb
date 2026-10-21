# frozen_string_literal: true

# Asks the provider for the status of one sent order, one run per order at a time. A refusal for the limit puts the job
# off for the wait the provider asked: the lock is given back as the run starts, so the job can queue itself again.
class Orders::Bookings::StatusRefreshWorker < ApplicationWorker
  sidekiq_options lock: :until_and_while_executing, on_conflict: { client: :log, server: :reschedule }

  def perform(order_id)
    order = Order.submitted.find_by(id: order_id)
    return unless order

    answer = Orders::Bookings::RefreshStatus.call(order)
    return unless answer.is_a?(Orders::Bookings::Failure) && answer.rate_limited?

    self.class.perform_in(answer.retry_after, order_id)
  end
end
