# frozen_string_literal: true

# What to show for the status the provider sent. A status Health24 knows gets its Ukrainian name; any other is shown as
# the provider wrote it, with the provider's comment, and never blocks the order from being shown. Intermediate
# statuses are not merged into states of our own.
class Orders::PartnerStatuses::Describe
  SCOPE = 'orders.partner_statuses'
  Result = Data.define(:title, :comment, :known)

  def self.call(order) = new(order).call

  def initialize(order)
    @order = order
  end

  def call
    name = @order.status_name
    translated = name.present? ? I18n.t(name, scope: SCOPE, default: nil) : nil
    Result.new(title: translated || name, comment: @order.status_comment, known: !translated.nil?)
  end
end
