# frozen_string_literal: true

# Cancels a booking at its provider (`DELETE` of a booked order) for the user of the order's account: the token is
# also the link a booking is shared by, so holding it is not enough. Only an order the provider took and whose status
# is not final can be cancelled. The partner's answer is not documented, so the status is read again after it.
class Orders::Bookings::Cancel
  # The order after the cancellation and whether its status was read again. When it was not, the provider took the
  # cancellation but the kept status is from before it, and a refresh is queued.
  Result = Data.define(:order, :confirmed)

  REASON_LENGTH = 255
  DEFAULT_REASON = 'Скасовано клієнтом'

  def self.call(owner, reason: nil) = new(owner, reason).call

  def initialize(owner, reason)
    @owner = owner
    @reason = reason
  end

  def call
    order = cancellable
    answer = adapter(order).cancel(order, reason:)
    refused(answer) if answer.is_a?(Orders::Bookings::Failure)

    read = Orders::Bookings::RefreshStatus.call(order)
    return Result.new(order:, confirmed: true) unless read.is_a?(Orders::Bookings::Failure)

    Orders::Bookings::StatusRefreshWorker.perform_async(order.id)
    Result.new(order:, confirmed: false)
  end

  private

  def cancellable
    order = Order.where.not(state: 'cart').find_by(token: @owner.token) || refuse(:cart_not_found, :not_found)
    policy = OrderPolicy.new(@owner, order)
    refuse(:cart_not_found, :not_found) unless policy.show?
    refuse(:cancellation_needs_account, :forbidden) unless policy.cancel?
    unless order.submitted? && !Orders::Bookings.config.final?(order.status_name)
      refuse(:order_not_cancellable, :conflict)
    end

    order
  end

  def reason
    text = @reason.to_s.squish
    refuse(:invalid_cancel_reason, :unprocessable_content) if text.length > REASON_LENGTH
    text.presence || DEFAULT_REASON
  end

  def refused(failure)
    case failure.reason
    when :rate_limited
      raise Orders::Carts::Refused.new(
        :cancellation_busy,
        status: :service_unavailable,
        retry_after: failure.retry_after
      )
    when :refused then refuse(:cancellation_refused, :conflict)
    else refuse(:cancellation_unavailable, :service_unavailable)
    end
  end

  def adapter(order)
    Orders::Bookings::Adapters.for(order.provider) || refuse(:cancellation_unavailable, :service_unavailable)
  end

  def refuse(code, status) = raise(Orders::Carts::Refused.new(code, status:))
end
