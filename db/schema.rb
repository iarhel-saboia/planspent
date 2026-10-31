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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_140000) do
  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "gray", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.string "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.integer "kind", default: 0, null: false
    t.date "occurred_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "category_id"
    t.integer "categorization", default: 0, null: false
    t.integer "goal_id"
    t.index ["category_id"], name: "index_entries_on_category_id"
    t.index ["goal_id"], name: "index_entries_on_goal_id"
    t.index ["occurred_on"], name: "index_entries_on_occurred_on"
  end

  create_table "goals", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "target_amount", precision: 12, scale: 2
    t.date "target_date"
    t.string "color", default: "indigo", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "kind", default: 0, null: false
    t.decimal "target_percent", precision: 5, scale: 2
  end

  create_table "merchant_categories", force: :cascade do |t|
    t.string "pattern", null: false
    t.integer "category_id", null: false
    t.integer "source", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_merchant_categories_on_category_id"
    t.index ["pattern"], name: "index_merchant_categories_on_pattern", unique: true
  end

  add_foreign_key "entries", "categories", on_delete: :nullify
  add_foreign_key "entries", "goals", on_delete: :nullify
  add_foreign_key "merchant_categories", "categories", on_delete: :cascade
end
