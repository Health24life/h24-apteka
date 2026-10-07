# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::LogRetention do
  let(:now) { Time.zone.parse('2026-10-07 12:00') }
  let(:config) { pharmapoint_config }

  def entry(category, age) = create(:provider_request_log, category:, created_at: now - age)

  def purge(**) = described_class.call(config: pharmapoint_config(**), now:)

  it 'removes each category after its own period', :aggregate_failures do
    kept = [ entry('booking', 10.days), entry('refresh', 2.days), entry('search', 1.hour) ]
    removed = [ entry('search', 2.days), entry('refresh', 8.days), entry('booking', 15.days) ]

    purge

    expect(ProviderRequestLog.all).to match_array(kept)
    expect(ProviderRequestLog.where(id: removed)).to be_empty
  end

  it 'reports how many entries it removed' do
    entry('search', 3.days)
    entry('search', 5.days)

    expect(purge).to eq(2)
  end

  it 'applies a period changed for one category and leaves the others', :aggregate_failures do
    search = entry('search', 3.days)
    refresh = entry('refresh', 3.days)

    purge(retention_days: { 'booking' => 14, 'search' => 7, 'refresh' => 1, 'other' => 7 })

    expect(ProviderRequestLog.where(id: search)).to exist
    expect(ProviderRequestLog.where(id: refresh)).to be_empty
  end

  it 'keeps a category that has no period of its own for the period of the other category', :aggregate_failures do
    old = entry('booking', 10.days)
    fresh = entry('booking', 8.days)

    purge(retention_days: { 'search' => 1, 'other' => 9 })

    expect(ProviderRequestLog.where(id: old)).to be_empty
    expect(ProviderRequestLog.where(id: fresh)).to exist
  end

  it 'removes a large number of entries in batches' do
    stub_const("#{described_class}::BATCH", 2)
    5.times { entry('search', 3.days) }

    expect { purge }.to change(ProviderRequestLog, :count).from(5).to(0)
  end

  it 'leaves the entries linked to a run alone when the run is gone, as they are kept by their own period' do
    log = entry('refresh', 1.day)
    log.sync_run = create(:sync_run)
    log.save!

    expect { purge }.not_to change(ProviderRequestLog, :count)
  end
end
