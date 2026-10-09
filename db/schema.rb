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

ActiveRecord::Schema[8.1].define(version: 2026_10_06_120002) do
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

  create_table "catalog_atc_class_hierarchies", primary_key: ["ancestor_id", "descendant_id", "generations"], force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["descendant_id"], name: "index_catalog_atc_class_hierarchies_on_descendant_id"
  end

  create_table "catalog_atc_classes", force: :cascade do |t|
    t.bigint "parent_id"
    t.string "atc_code", null: false
    t.jsonb "name", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atc_code"], name: "index_catalog_atc_classes_on_atc_code", unique: true
    t.index ["parent_id"], name: "index_catalog_atc_classes_on_parent_id"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "catalog_atc_classes_parent_check"
  end

  create_table "catalog_categories", force: :cascade do |t|
    t.bigint "parent_id"
    t.string "slug", null: false
    t.jsonb "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_catalog_categories_on_parent_id"
    t.index ["slug"], name: "index_catalog_categories_on_slug", unique: true
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "catalog_categories_parent_check"
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100", name: "catalog_categories_slug_check"
  end

  create_table "catalog_category_hierarchies", primary_key: ["ancestor_id", "descendant_id", "generations"], force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["descendant_id"], name: "index_catalog_category_hierarchies_on_descendant_id"
  end

  create_table "catalog_drugstore_addresses", force: :cascade do |t|
    t.bigint "drugstore_id", null: false
    t.string "address", null: false
    t.string "city"
    t.string "state"
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.bigint "core_region_id"
    t.bigint "core_settlement_id"
    t.bigint "core_city_district_id"
    t.bigint "core_metro_station_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["drugstore_id"], name: "index_catalog_drugstore_addresses_on_drugstore_id", unique: true
    t.check_constraint "latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "catalog_drugstore_addresses_latitude_check"
    t.check_constraint "longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "catalog_drugstore_addresses_longitude_check"
  end

  create_table "catalog_drugstore_brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "image_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_drugstores", force: :cascade do |t|
    t.bigint "brand_id"
    t.string "name"
    t.string "drugstore_legal_entity_name", null: false
    t.string "drugstore_legal_entity_code", null: false
    t.string "phone"
    t.string "mobile_phone"
    t.string "email"
    t.string "ext_drugstore_id"
    t.jsonb "week_working_hours", default: [], null: false
    t.boolean "work_with_reimbursement", default: false, null: false
    t.boolean "withdrawn", default: false, null: false
    t.boolean "hidden", default: false, null: false
    t.boolean "incomplete", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_catalog_drugstores_on_brand_id"
    t.check_constraint "drugstore_legal_entity_code::text ~ '^[0-9]{8}([0-9]{2})?$'::text", name: "catalog_drugstores_legal_entity_code_check"
    t.check_constraint "jsonb_array_length(week_working_hours) = ANY (ARRAY[0, 7])", name: "catalog_drugstores_week_hours_check"
  end

  create_table "catalog_goods", force: :cascade do |t|
    t.bigint "goods_group_id", null: false
    t.bigint "form_id"
    t.bigint "measure_id"
    t.bigint "price_group_id"
    t.bigint "temperature_mode_id"
    t.bigint "adult_restriction_id"
    t.bigint "child_restriction_id"
    t.bigint "diabetic_restriction_id"
    t.bigint "driver_restriction_id"
    t.bigint "pregnant_and_lactating_restriction_id"
    t.integer "core_inn_id"
    t.string "dosage"
    t.text "composition"
    t.string "mnn"
    t.string "release_form"
    t.string "morion_code"
    t.string "pack_unit_name"
    t.integer "pack_quantity_in_pack"
    t.integer "pack_quantity_unit_in_pack"
    t.integer "pack_quantity_in_unit"
    t.jsonb "image_paths", default: [], null: false
    t.boolean "is_recipe", default: false, null: false
    t.boolean "is_strict_recipe", default: false, null: false
    t.boolean "in_medication_program", default: false, null: false
    t.boolean "withdrawn", default: false, null: false
    t.boolean "hidden", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", null: false
    t.text "instruction_source_html"
    t.index ["goods_group_id"], name: "index_catalog_goods_on_goods_group_id"
    t.index ["slug"], name: "index_catalog_goods_on_slug", unique: true
    t.check_constraint "jsonb_typeof(image_paths) = 'array'::text", name: "catalog_goods_image_paths_check"
    t.check_constraint "pack_quantity_in_pack IS NULL OR pack_quantity_in_pack >= 0", name: "catalog_goods_in_pack_check"
    t.check_constraint "pack_quantity_in_unit IS NULL OR pack_quantity_in_unit >= 0", name: "catalog_goods_in_unit_check"
    t.check_constraint "pack_quantity_unit_in_pack IS NULL OR pack_quantity_unit_in_pack >= 0", name: "catalog_goods_unit_in_pack_check"
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100", name: "catalog_goods_slug_check"
  end

  create_table "catalog_goods_forms", force: :cascade do |t|
    t.jsonb "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_goods_group_categories", force: :cascade do |t|
    t.bigint "goods_group_id", null: false
    t.bigint "category_id", null: false
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_catalog_goods_group_categories_on_category_id"
    t.index ["goods_group_id", "category_id"], name: "index_catalog_goods_group_categories_uniqueness", unique: true
    t.index ["goods_group_id"], name: "index_catalog_goods_group_categories_primary", unique: true, where: "is_primary"
  end

  create_table "catalog_goods_group_translations", force: :cascade do |t|
    t.bigint "catalog_goods_group_id", null: false
    t.string "locale", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_goods_group_id", "locale"], name: "index_catalog_goods_group_translations_uniqueness", unique: true
  end

  create_table "catalog_goods_groups", force: :cascade do |t|
    t.bigint "producer_id"
    t.bigint "goods_name_id"
    t.bigint "atc_class_id"
    t.boolean "included_to_offers", default: false, null: false
    t.boolean "withdrawn", default: false, null: false
    t.boolean "hidden", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atc_class_id"], name: "index_catalog_goods_groups_on_atc_class_id"
    t.index ["goods_name_id"], name: "index_catalog_goods_groups_on_goods_name_id"
    t.index ["producer_id"], name: "index_catalog_goods_groups_on_producer_id"
  end

  create_table "catalog_goods_instruction_section_translations", force: :cascade do |t|
    t.bigint "catalog_goods_instruction_section_id", null: false
    t.string "locale", null: false
    t.text "body_html"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_goods_instruction_section_id", "locale"], name: "index_catalog_instruction_section_translations_uniqueness", unique: true
  end

  create_table "catalog_goods_instruction_sections", force: :cascade do |t|
    t.bigint "goods_id", null: false
    t.integer "position", null: false
    t.string "code", null: false
    t.string "anchor", null: false
    t.string "source_title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_id", "anchor"], name: "index_catalog_instruction_sections_on_goods_and_anchor", unique: true
    t.index ["goods_id", "position"], name: "index_catalog_instruction_sections_on_goods_and_position", unique: true
    t.check_constraint "\"position\" >= 1", name: "catalog_goods_instruction_sections_position_check"
    t.check_constraint "anchor::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "catalog_goods_instruction_sections_anchor_check"
  end

  create_table "catalog_goods_measures", force: :cascade do |t|
    t.jsonb "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_goods_names", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_goods_price_groups", force: :cascade do |t|
    t.jsonb "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_goods_restrictions", force: :cascade do |t|
    t.jsonb "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_goods_temperature_modes", force: :cascade do |t|
    t.jsonb "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_goods_translations", force: :cascade do |t|
    t.bigint "catalog_goods_id", null: false
    t.string "locale", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "instruction_html"
    t.index ["catalog_goods_id", "locale"], name: "index_catalog_goods_translations_uniqueness", unique: true
  end

  create_table "catalog_producers", force: :cascade do |t|
    t.string "name", null: false
    t.string "country"
    t.string "country_code", limit: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "country_code IS NULL OR country_code::text ~ '^[A-Z]{2}$'::text", name: "catalog_producers_country_code_check"
  end

  create_table "provider_links", force: :cascade do |t|
    t.bigint "provider_id", null: false
    t.string "linkable_type", null: false
    t.bigint "linkable_id", null: false
    t.string "external_id", null: false
    t.jsonb "attrs", default: {}, null: false
    t.datetime "synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["linkable_type", "linkable_id"], name: "index_provider_links_on_linkable"
    t.index ["provider_id", "linkable_type", "external_id"], name: "index_provider_links_on_provider_external_id", unique: true
    t.index ["provider_id", "linkable_type", "linkable_id"], name: "index_provider_links_on_provider_linkable", unique: true
    t.check_constraint "linkable_type::text = ANY (ARRAY['Catalog::Drugstore::Brand'::character varying, 'Catalog::Goods::Form'::character varying, 'Catalog::Goods::Measure'::character varying, 'Catalog::Goods::PriceGroup'::character varying, 'Catalog::Goods::TemperatureMode'::character varying, 'Catalog::Goods::Restriction'::character varying, 'Catalog::Category'::character varying, 'Catalog::Producer'::character varying, 'Catalog::Goods::Name'::character varying, 'Catalog::AtcClass'::character varying, 'Catalog::Goods::Group'::character varying, 'Catalog::Goods'::character varying, 'Catalog::Drugstore'::character varying]::text[])", name: "provider_links_linkable_type_check"
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
    t.check_constraint "kind::text = ANY (ARRAY['external'::character varying::text, 'own'::character varying::text])", name: "providers_kind_check"
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
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying::text, 'succeeded'::character varying::text, 'completed_with_failures'::character varying::text, 'failed'::character varying::text])", name: "sync_runs_status_check"
  end

  add_foreign_key "catalog_atc_class_hierarchies", "catalog_atc_classes", column: "ancestor_id", on_delete: :cascade
  add_foreign_key "catalog_atc_class_hierarchies", "catalog_atc_classes", column: "descendant_id", on_delete: :cascade
  add_foreign_key "catalog_atc_classes", "catalog_atc_classes", column: "parent_id"
  add_foreign_key "catalog_categories", "catalog_categories", column: "parent_id"
  add_foreign_key "catalog_category_hierarchies", "catalog_categories", column: "ancestor_id", on_delete: :cascade
  add_foreign_key "catalog_category_hierarchies", "catalog_categories", column: "descendant_id", on_delete: :cascade
  add_foreign_key "catalog_drugstore_addresses", "catalog_drugstores", column: "drugstore_id", on_delete: :cascade
  add_foreign_key "catalog_drugstores", "catalog_drugstore_brands", column: "brand_id"
  add_foreign_key "catalog_goods", "catalog_goods_forms", column: "form_id"
  add_foreign_key "catalog_goods", "catalog_goods_groups", column: "goods_group_id"
  add_foreign_key "catalog_goods", "catalog_goods_measures", column: "measure_id"
  add_foreign_key "catalog_goods", "catalog_goods_price_groups", column: "price_group_id"
  add_foreign_key "catalog_goods", "catalog_goods_restrictions", column: "adult_restriction_id"
  add_foreign_key "catalog_goods", "catalog_goods_restrictions", column: "child_restriction_id"
  add_foreign_key "catalog_goods", "catalog_goods_restrictions", column: "diabetic_restriction_id"
  add_foreign_key "catalog_goods", "catalog_goods_restrictions", column: "driver_restriction_id"
  add_foreign_key "catalog_goods", "catalog_goods_restrictions", column: "pregnant_and_lactating_restriction_id"
  add_foreign_key "catalog_goods", "catalog_goods_temperature_modes", column: "temperature_mode_id"
  add_foreign_key "catalog_goods_group_categories", "catalog_categories", column: "category_id"
  add_foreign_key "catalog_goods_group_categories", "catalog_goods_groups", column: "goods_group_id", on_delete: :cascade
  add_foreign_key "catalog_goods_group_translations", "catalog_goods_groups", on_delete: :cascade
  add_foreign_key "catalog_goods_groups", "catalog_atc_classes", column: "atc_class_id"
  add_foreign_key "catalog_goods_groups", "catalog_goods_names", column: "goods_name_id"
  add_foreign_key "catalog_goods_groups", "catalog_producers", column: "producer_id"
  add_foreign_key "catalog_goods_instruction_section_translations", "catalog_goods_instruction_sections", on_delete: :cascade
  add_foreign_key "catalog_goods_instruction_sections", "catalog_goods", column: "goods_id"
  add_foreign_key "catalog_goods_translations", "catalog_goods", on_delete: :cascade
  add_foreign_key "provider_links", "providers"
  add_foreign_key "sync_run_failures", "sync_runs", on_delete: :cascade
  add_foreign_key "sync_runs", "providers"
end
