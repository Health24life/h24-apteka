class CreateSeoVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_versions do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :event, null: false
      t.string :whodunnit
      t.jsonb :object
      t.jsonb :object_changes
      t.references :owner, polymorphic: true, index: false
      t.references :author, polymorphic: true, index: false

      t.datetime :created_at, null: false
    end

    add_index :seo_versions, %i[item_type item_id]
    add_index :seo_versions, %i[owner_type owner_id created_at]
    add_index :seo_versions, %i[author_type author_id]
    add_index :seo_versions, :created_at
  end
end
