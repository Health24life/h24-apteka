# frozen_string_literal: true

class Pillbox::PlanItem < ApplicationRecord
  NAME_LENGTH = 255
  DOSAGE_LENGTH = 100
  EVERY_N = 1..99
  # 0 is Sunday, as Date#wday and JavaScript count.
  WEEKDAYS = 0..6
  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/
  MAX_TIMES = 6
  COURSE_DAYS = 1..365
  MAX_COURSE_END = 365

  enum :source, { order: 'order', catalog: 'catalog', manual: 'manual' }, prefix: true, validate: true
  enum :every_unit, { day: 'day', week: 'week', month: 'month' }, prefix: :every, validate: true
  enum :course_mode, { days: 'days', until: 'until', open: 'open' }, prefix: :term, validate: true
  enum :reminder_mode, { once: 'once', until_marked: 'until_marked' }, prefix: :remind, validate: true

  belongs_to :plan, class_name: 'Pillbox::Plan', inverse_of: :items
  # The client keeps the source and the SKU consistent; only the SKU being in the catalog is checked.
  belongs_to :goods, class_name: 'Catalog::Goods', optional: true, inverse_of: false
  has_many :intakes, class_name: 'Pillbox::Intake', inverse_of: :plan_item, dependent: nil

  validates :name, length: { maximum: NAME_LENGTH }
  validates :dosage, length: { maximum: DOSAGE_LENGTH }
  validates :every_n, numericality: { only_integer: true, in: EVERY_N }
  validates :course_days, numericality: { only_integer: true, in: COURSE_DAYS }, if: :term_days?
  validates :course_end_date, presence: true, if: :term_until?
  validates_with Pillbox::PlanItemValidator

  scope :kept, -> { where(discarded_at: nil) }

  normalizes :times, with: ->(times) { Array.wrap(times).map { |time| time.to_s.strip }.sort }, apply_to_nil: true

  def normalize! = Pillbox::PlanItems::Normalize.call(self)
end

# == Schema Information
#
# Table name: pillbox_plan_items
#
#  id                :bigint           not null, primary key
#  anchor_date       :date             not null
#  course_days       :integer
#  course_end_date   :date
#  course_mode       :string           not null
#  course_start_date :date             not null
#  discarded_at      :datetime
#  dosage            :string
#  every_n           :integer          default(1), not null
#  every_unit        :string           not null
#  missed_until      :datetime         not null
#  name              :string
#  position          :integer          default(0), not null
#  reminder_mode     :string           default("once"), not null
#  schedule_version  :integer          default(1), not null
#  source            :string           not null
#  times             :jsonb            not null
#  weekdays          :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  goods_id          :bigint
#  plan_id           :bigint           not null
#  user_id           :integer          not null
#
# Indexes
#
#  index_pillbox_plan_items_on_goods_id  (goods_id)
#  index_pillbox_plan_items_on_plan_id   (plan_id)
#  index_pillbox_plan_items_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (goods_id => catalog_goods.id) ON DELETE => nullify
#  fk_rails_...  (plan_id => pillbox_plans.id) ON DELETE => cascade
#
