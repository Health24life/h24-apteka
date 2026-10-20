# frozen_string_literal: true

# Who may do what with an order reached by its token. The user is the one who asks (Orders::Carts::Owner). The token is
# the one key, also the link a booking is shared by, so the rules tell the owner of an account from whoever holds the
# link.
class OrderPolicy < ApplicationPolicy
  # Change the cart or book it: an order of a guest to whoever holds its token, an order of an account only to its user.
  def open? = record.user_id.nil? || record.user_id == user.user_id

  # A cart opens as `open?` does; a sent order opens to whoever holds the link, so someone else can pick it up.
  def show? = record.cart? ? open? : true

  # The client's name, phone and email, only to the signed-in user of the account the order is in.
  def personal_data? = !record.user_id.nil? && record.user_id == user.user_id

  # Cancel a booking: the token is also the link it is shared by, so only the user of the account may.
  def cancel? = personal_data?
end
