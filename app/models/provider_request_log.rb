# frozen_string_literal: true

# One attempt of one call to a provider, with both bodies and headers as they went over the wire (secrets masked).
class ProviderRequestLog < ApplicationRecord
  # An outcome with no answer from the provider has no status code, and any other outcome has one.
  WITHOUT_RESPONSE = %w[timeout connection_error].freeze

  enum :category, { booking: 'booking', search: 'search', refresh: 'refresh', other: 'other' }, validate: true
  enum :outcome, { success: 'success', http_error: 'http_error', timeout: 'timeout',
                   connection_error: 'connection_error', invalid_response: 'invalid_response' }, validate: true

  belongs_to :provider, inverse_of: :request_logs
  belongs_to :sync_run, optional: true, inverse_of: :request_logs
  # The user lives in the core database, so there is no foreign key.
  belongs_to :user, class_name: 'H24Core::User', optional: true, inverse_of: false

  validates :http_method, :path, presence: true
  validates :attempt, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :duration_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :status_matches_outcome

  scope :older_than, ->(time) { where(created_at: ...time) }

  private

  def status_matches_outcome
    return if outcome.nil? || WITHOUT_RESPONSE.include?(outcome) == response_status.nil?

    errors.add(:response_status, :invalid)
  end
end

# == Schema Information
#
# Table name: provider_request_logs
#
#  id               :bigint           not null, primary key
#  attempt          :integer          default(1), not null
#  category         :string           not null
#  duration_ms      :integer          default(0), not null
#  error_class      :string
#  http_method      :string           not null
#  outcome          :string           not null
#  path             :string           not null
#  query            :jsonb            not null
#  request_body     :jsonb
#  request_headers  :jsonb            not null
#  response_body    :jsonb
#  response_headers :jsonb            not null
#  response_status  :integer
#  created_at       :datetime         not null
#  provider_id      :bigint           not null
#  sync_run_id      :bigint
#  user_id          :integer
#
# Indexes
#
#  index_provider_request_logs_on_category_and_created_at  (category,created_at)
#  index_provider_request_logs_on_provider_id              (provider_id)
#  index_provider_request_logs_on_sync_run_id              (sync_run_id)
#  index_provider_request_logs_on_user_id_and_created_at   (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (provider_id => providers.id)
#  fk_rails_...  (sync_run_id => sync_runs.id) ON DELETE => nullify
#
# Check Constraints
#
#  provider_request_logs_attempt_check   (attempt >= 1)
#  provider_request_logs_category_check  (category::text = ANY (ARRAY['booking'::character varying, 'search'::character varying, 'refresh'::character varying, 'other'::character varying]::text[]))
#  provider_request_logs_duration_check  (duration_ms >= 0)
#  provider_request_logs_outcome_check   (outcome::text = ANY (ARRAY['success'::character varying, 'http_error'::character varying, 'timeout'::character varying, 'connection_error'::character varying, 'invalid_response'::character varying]::text[]))
#  provider_request_logs_status_check    ((outcome::text = ANY (ARRAY['timeout'::character varying, 'connection_error'::character varying]::text[])) = (response_status IS NULL))
#
