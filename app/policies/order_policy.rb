# frozen_string_literal: true

# Who may open an order reached by its token. The user is the one who asks (Orders::Carts::Owner): an order of a guest
# opens to whoever holds its token, an order of an account only to the user of that account.
class OrderPolicy < ApplicationPolicy
  def open? = record.user_id.nil? || record.user_id == user.user_id
end
