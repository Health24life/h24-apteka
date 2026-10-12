# frozen_string_literal: true

FactoryBot.define do
  factory :provider_request_log, class: 'Provider::RequestLog' do
    provider
    category { 'refresh' }
    http_method { 'GET' }
    path { '/goods-group/search' }
    outcome { 'success' }
    response_status { 200 }

    trait :without_response do
      outcome { 'timeout' }
      response_status { nil }
    end
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
