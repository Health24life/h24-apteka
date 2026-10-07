# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::LogCleanupWorker do
  it 'removes the entries that outlived their period' do
    create(:provider_request_log, category: 'search', created_at: 3.days.ago)
    create(:provider_request_log, category: 'search', created_at: 1.hour.ago)

    expect { described_class.new.perform }.to change(Provider::RequestLog, :count).from(2).to(1)
  end
end
