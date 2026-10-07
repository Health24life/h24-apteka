# frozen_string_literal: true

# Gives an order the Health24 number the provider knows it by. The number is only assigned, not saved: the caller saves
# it together with the new state. An order that has a number keeps it, because after a failed submission the provider
# recognises the retry by that number.
class Orders::AssignOwnNumber
  LENGTH = 10
  ALPHABET = [ *'A'..'Z', *'0'..'9' ].freeze

  def self.call(order) = new(order).call

  def initialize(order)
    @order = order
  end

  def call
    @order.own_number = free_number if @order.own_number.blank?
    @order
  end

  private

  # The unique index decides in the end; this only spares it a collision in the usual case.
  def free_number
    loop do
      candidate = Array.new(LENGTH) { ALPHABET.sample }.join
      return candidate unless Order.exists?(own_number: candidate)
    end
  end
end
