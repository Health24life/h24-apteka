class CreatePillboxTables < ActiveRecord::Migration[8.1]
  def change
    create_table :pillbox_plans do |t|
      t.integer :user_id, null: false
      t.references :source_order, foreign_key: { to_table: :orders, on_delete: :nullify }
      t.string :status, null: false, default: 'active'
      t.string :timezone, null: false
      t.string :title, null: false
      t.integer :missed_days, null: false, default: 0
      t.datetime :paused_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :pillbox_plans, :user_id
    add_index :pillbox_plans, :timezone

    create_table :pillbox_plan_items do |t|
      t.references :plan, null: false, foreign_key: { to_table: :pillbox_plans, on_delete: :cascade }
      t.references :goods, foreign_key: { to_table: :catalog_goods, on_delete: :nullify }
      t.integer :user_id, null: false
      t.string :source, null: false
      t.string :name
      t.string :dosage
      t.integer :position, null: false, default: 0
      t.jsonb :times, null: false, default: []
      t.integer :every_n, null: false, default: 1
      t.string :every_unit, null: false
      t.jsonb :weekdays, null: false, default: []
      t.date :anchor_date, null: false
      t.string :course_mode, null: false
      t.date :course_start_date, null: false
      t.integer :course_days
      t.date :course_end_date
      t.string :reminder_mode, null: false, default: 'once'
      t.datetime :missed_until, null: false
      t.integer :schedule_version, null: false, default: 1
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :pillbox_plan_items, :user_id

    create_table :pillbox_intakes do |t|
      t.references :plan, null: false, index: false, foreign_key: { to_table: :pillbox_plans, on_delete: :cascade }
      t.references :plan_item, null: false, index: false,
                               foreign_key: { to_table: :pillbox_plan_items, on_delete: :cascade }
      t.date :scheduled_date, null: false
      t.string :scheduled_time, null: false
      t.datetime :due_at, null: false
      t.string :status, null: false
      t.string :marked_via
      t.datetime :taken_at
      t.timestamps
    end

    add_index :pillbox_intakes, %i[plan_id scheduled_date]
    add_index :pillbox_intakes, %i[plan_item_id scheduled_date]
  end
end
