# frozen_string_literal: true

# Takes a SKU or a drugstore out of the user's list, whether the catalog still shows it or not. A record that is not in
# the list is no error.
class Favorites::Entries::Remove
  def self.call(kind, user_id:, target_id:)
    kind.model.where(user_id:).where(kind.key => target_id).delete_all
  end
end
