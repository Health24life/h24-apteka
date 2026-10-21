# frozen_string_literal: true

# Puts a status refresh in the queue for every sent order whose status is still asked about. The partner has no
# webhooks, so this is how a booking learns what the drugstore did.
class Orders::Bookings::StatusPollWorker < ApplicationWorker
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform
    Orders::Bookings::DueForStatus.call.in_batches(of: 500).each_record do |order|
      Orders::Bookings::StatusRefreshWorker.perform_async(order.id)
    end
  end
end
