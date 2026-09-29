# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_29_080829) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "providers", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.boolean "active", default: true, null: false
    t.boolean "supports_delivery", default: false, null: false
    t.boolean "supports_e_recipe", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_providers_on_code", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['external'::character varying, 'own'::character varying]::text[])", name: "providers_kind_check"
  end

  create_table "sync_run_failures", force: :cascade do |t|
    t.bigint "sync_run_id", null: false
    t.string "entity_type", null: false
    t.string "external_id", null: false
    t.string "error_class", null: false
    t.text "message"
    t.jsonb "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sync_run_id"], name: "index_sync_run_failures_on_sync_run_id"
  end

  create_table "sync_runs", force: :cascade do |t|
    t.bigint "provider_id", null: false
    t.string "kind", null: false
    t.string "status", default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "processed_count", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.jsonb "progress", default: {}, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id", "kind", "started_at"], name: "index_sync_runs_on_provider_id_and_kind_and_started_at"
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'completed_with_failures'::character varying, 'failed'::character varying]::text[])", name: "sync_runs_status_check"
  end

  add_foreign_key "sync_run_failures", "sync_runs", on_delete: :cascade
  add_foreign_key "sync_runs", "providers"
end
