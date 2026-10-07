# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProviderRequestLog do
  subject(:log) { build(:provider_request_log) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:provider) }
  it { is_expected.to belong_to(:sync_run).optional }
  it { is_expected.to validate_presence_of(:http_method) }
  it { is_expected.to validate_presence_of(:path) }
  it { is_expected.to validate_numericality_of(:attempt).only_integer.is_greater_than_or_equal_to(1) }
  it { is_expected.to validate_numericality_of(:duration_ms).only_integer.is_greater_than_or_equal_to(0) }

  it 'accepts only known categories and outcomes', :aggregate_failures do
    expect(build(:provider_request_log, category: 'booking')).to be_valid
    expect(build(:provider_request_log, category: 'payments')).not_to be_valid
    expect(build(:provider_request_log, outcome: 'success')).to be_valid
    expect(build(:provider_request_log, outcome: 'partial')).not_to be_valid
  end

  it 'has no status code when the provider did not answer, and has one otherwise', :aggregate_failures do
    expect(build(:provider_request_log, :without_response)).to be_valid
    expect(build(:provider_request_log, :without_response, response_status: 504)).not_to be_valid
    expect(build(:provider_request_log, outcome: 'http_error', response_status: nil)).not_to be_valid
  end

  it 'keeps the status code and the outcome in separate columns' do
    log = create(:provider_request_log, outcome: 'http_error', response_status: 503)

    expect(described_class.where(response_status: 503, outcome: 'http_error')).to contain_exactly(log)
  end

  it 'keeps headers and bodies as JSON, including a body that is only text' do
    log = create(:provider_request_log, request_headers: { 'accept' => 'application/json' },
                                        response_headers: { 'x-ratelimit-remaining' => '12' },
                                        request_body: { 'a' => 1 }, response_body: 'Bad gateway')

    expect(log.reload).to have_attributes(response_headers: { 'x-ratelimit-remaining' => '12' },
                                          request_body: { 'a' => 1 }, response_body: 'Bad gateway')
  end

  it 'is kept when its sync run is removed, without the link to it' do
    run = create(:sync_run)
    log = create(:provider_request_log, sync_run: run)

    run.destroy!

    expect(log.reload.sync_run_id).to be_nil
  end

  it 'is refused to be deleted together with a provider that still has logs' do
    log = create(:provider_request_log)

    expect { log.provider.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  describe '.older_than' do
    it 'selects entries created before the moment' do
      old = create(:provider_request_log, created_at: 3.days.ago)
      create(:provider_request_log, created_at: 1.hour.ago)

      expect(described_class.older_than(1.day.ago)).to contain_exactly(old)
    end
  end
end
