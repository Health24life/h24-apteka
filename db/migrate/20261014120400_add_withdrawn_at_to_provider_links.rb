# frozen_string_literal: true

class AddWithdrawnAtToProviderLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :provider_links, :withdrawn_at, :datetime
  end
end
