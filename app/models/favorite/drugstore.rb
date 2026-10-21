# frozen_string_literal: true

# A drugstore a user keeps in «Мої аптеки». It stays when the drugstore is hidden or withdrawn later; the database drops
# it with the drugstore. The core lives in another database, so the user has no foreign key.
class Favorite::Drugstore < ApplicationRecord
  belongs_to :drugstore, class_name: 'Catalog::Drugstore', inverse_of: false
end

# == Schema Information
#
# Table name: favorite_drugstores
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  drugstore_id :bigint           not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_favorite_drugstores_on_drugstore_id              (drugstore_id)
#  index_favorite_drugstores_on_user_id_and_drugstore_id  (user_id,drugstore_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (drugstore_id => catalog_drugstores.id) ON DELETE => cascade
#
