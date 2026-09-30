# frozen_string_literal: true

class SyncRun < ApplicationRecord
  KINDS = %w[dictionaries categories goods_groups drugstores].freeze
  STATUSES = %w[running succeeded completed_with_failures failed].freeze

  enum :kind, KINDS.index_with(&:itself), validate: true
  enum :status, STATUSES.index_with(&:itself), validate: true

  belongs_to :provider, inverse_of: :sync_runs

  has_many :failures, class_name: 'SyncRun::Failure', inverse_of: :sync_run, dependent: :delete_all

  validates :started_at, presence: true
  validates :finished_at, presence: true, unless: :running?
  validates :processed_count, :failed_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :finished_after_start

  scope :finished_successfully, -> { where(status: %w[succeeded completed_with_failures]) }

  def self.last_successful(provider, kind)
    where(provider:, kind:).finished_successfully.order(started_at: :desc).first
  end

  private

  def finished_after_start
    finished = finished_at
    started = started_at
    return if finished.nil? || started.nil? || finished >= started

    errors.add(:finished_at, :before_start)
  end
end

# == Schema Information
#
# Table name: sync_runs
#
#  id              :bigint           not null, primary key
#  error_message   :text
#  failed_count    :integer          default(0), not null
#  finished_at     :datetime
#  kind            :string           not null
#  processed_count :integer          default(0), not null
#  progress        :jsonb            not null
#  started_at      :datetime         not null
#  status          :string           default("running"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  provider_id     :bigint           not null
#
# Indexes
#
#  index_sync_runs_on_provider_id_and_kind_and_started_at  (provider_id,kind,started_at)
#
# Foreign Keys
#
#  fk_rails_...  (provider_id => providers.id)
#
# Check Constraints
#
#  sync_runs_status_check  (status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'completed_with_failures'::character varying, 'failed'::character varying]::text[]))
#
