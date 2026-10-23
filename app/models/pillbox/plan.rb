# frozen_string_literal: true

class Pillbox::Plan < ApplicationRecord
  TITLE_LENGTH = 50
  MAX_ITEMS = 10
  MAX_OPEN_PLANS = 5
  TIMEZONES = TZInfo::Timezone.all_identifiers.to_set.freeze

  enum :status, { active: 'active', paused: 'paused', completed: 'completed' }, validate: true

  # Not stored: the items keep the start of their courses.
  attribute :start_date, :date

  belongs_to :user, class_name: 'H24Core::User', inverse_of: :pillbox_plans
  belongs_to :source_order, class_name: 'Order', optional: true, inverse_of: false
  # Items taken out of the plan stay, discarded, for the history.
  has_many :items,
           -> { where(discarded_at: nil).order(:position) },
           class_name: 'Pillbox::PlanItem',
           inverse_of: :plan,
           autosave: true,
           index_errors: true,
           dependent: nil
  has_many :all_items, class_name: 'Pillbox::PlanItem', inverse_of: false, dependent: nil
  has_many :intakes, class_name: 'Pillbox::Intake', inverse_of: :plan, dependent: nil

  validates :title, presence: true, length: { maximum: TITLE_LENGTH }
  validates :timezone, inclusion: { in: TIMEZONES }
  validates :items, presence: true
  validate :items_limit
  validate :open_plans_limit, on: :create
  validate :start_date_not_in_past, on: :create
  validate :source_order_of_user, unless: -> { source_order_id.nil? }

  scope :open_for, ->(user_id) { where(user_id:, status: %w[active paused]) }

  normalizes :title, with: -> { it.strip }

  accepts_nested_attributes_for :items

  def tz = ActiveSupport::TimeZone[timezone.to_s]

  def today
    zone = tz
    Time.current.in_time_zone(zone).to_date if zone
  end

  private

  def items_limit
    errors.add(:items, :too_many, count: MAX_ITEMS) if items.size > MAX_ITEMS
  end

  def open_plans_limit
    errors.add(:base, :too_many_plans, count: MAX_OPEN_PLANS) if self.class.open_for(user_id).count >= MAX_OPEN_PLANS
  end

  # A date sent but not recognised is refused rather than taken as today.
  def start_date_not_in_past
    return errors.add(:start_date, :invalid) if start_date.nil? && start_date_before_type_cast.present?

    date = start_date
    current = today
    errors.add(:start_date, :in_past) if date && current && date < current
  end

  def source_order_of_user
    return if Order.where(id: source_order_id, user_id:).where.not(state: :cart).exists?

    errors.add(:source_order_id, :invalid)
  end
end

# == Schema Information
#
# Table name: pillbox_plans
#
#  id              :bigint           not null, primary key
#  completed_at    :datetime
#  missed_days     :integer          default(0), not null
#  paused_at       :datetime
#  status          :string           default("active"), not null
#  timezone        :string           not null
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  source_order_id :bigint
#  user_id         :integer          not null
#
# Indexes
#
#  index_pillbox_plans_on_source_order_id  (source_order_id)
#  index_pillbox_plans_on_timezone         (timezone)
#  index_pillbox_plans_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (source_order_id => orders.id) ON DELETE => nullify
#
