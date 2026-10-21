# frozen_string_literal: true

# «Мої аптеки»: the drugstores of the user's list, the last added first, with what the directory knows of them. The
# provider is not asked.
class Favorites::Drugstores::List
  # A drugstore of the list, shown as a drugstore is everywhere else, and when it was added.
  class Row < Data.define(:drugstore, :added_at)
    delegate :id,
             :name,
             :brand,
             :address,
             :drugstore_legal_entity_name,
             :drugstore_legal_entity_code,
             :phone,
             :mobile_phone,
             :week_working_hours,
             :work_with_reimbursement,
             to: :drugstore

    def available? = drugstore.shown?
  end

  def self.call(user_id:)
    Favorite::Drugstore
      .where(user_id:)
      .includes(drugstore: %i[address brand])
      .order(created_at: :desc, id: :desc)
      .map { Row.new(drugstore: it.drugstore, added_at: it.created_at) }
  end
end
