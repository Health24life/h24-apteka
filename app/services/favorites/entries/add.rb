# frozen_string_literal: true

# Puts a SKU or a drugstore the catalog shows in the user's list. One already there stays as it is, in its place, even
# when the list is full, so a client may repeat the request after a lost answer.
class Favorites::Entries::Add
  def self.call(kind, user_id:, target_id:) = new(kind, user_id).call(target_id)

  def initialize(kind, user_id)
    @kind = kind
    @user_id = user_id
  end

  def call(target_id)
    target = @kind.target.shown.find_by(id: target_id) || refuse(@kind.not_found, :not_found)
    entries = @kind.model.where(user_id: @user_id)
    return if entries.exists?(@kind.key => target.id)

    refuse_when_full(entries)
    @kind.model.create!(user_id: @user_id, @kind.key => target.id)
  rescue ActiveRecord::RecordNotUnique
    # The same record, added by a request a moment earlier.
  end

  private

  def refuse_when_full(entries)
    limit = Favorites::LIMIT
    refuse(:favorites_limit_reached, :unprocessable_content, details: { limit: }) if entries.count >= limit
  end

  def refuse(code, status, details: nil)
    raise Favorites::Refused.new(code, status:, details:)
  end
end
