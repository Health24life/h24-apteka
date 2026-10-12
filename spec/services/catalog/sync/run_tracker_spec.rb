# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::RunTracker do
  let(:provider) { create(:provider) }
  let(:tracker) { described_class.start(provider:, kind: 'drugstores') }

  describe '.start' do
    it 'opens a running run of the kind', :aggregate_failures do
      expect(tracker.run).to have_attributes(provider:, kind: 'drugstores', status: 'running')
      expect(tracker.run.progress).to eq('mode' => 'full')
    end

    it 'opens nothing while a run of the same kind is running' do
      tracker

      expect(described_class.start(provider:, kind: 'drugstores')).to be_nil
    end

    it 'opens a run of another kind', :aggregate_failures do
      tracker

      expect(described_class.start(provider:, kind: 'categories')).to be_present
    end

    it 'closes a run that hung and opens a new one', :aggregate_failures do
      hung = create(:sync_run, provider:, kind: 'drugstores', started_at: 7.hours.ago)

      expect(tracker).to be_present
      expect(hung.reload).to have_attributes(status: 'failed', error_message: /did not finish in time/)
    end

    it 'is not held up by a fetch on demand that is still running' do
      described_class.pull(provider:, kind: 'drugstores')

      expect(tracker).to be_present
    end
  end

  describe '#guard' do
    it 'returns what the block returns' do
      expect(tracker.guard('Catalog::Drugstore', '1') { :saved }).to eq(:saved)
    end

    it 'writes the failure of one record to the journal and lets the run go on', :aggregate_failures do
      result = tracker.guard('Catalog::Drugstore', 42, { id: 42 }) { raise ArgumentError, 'broken' }

      expect(result).to be_nil
      expect(tracker.run.failures.sole).to have_attributes(entity_type: 'Catalog::Drugstore', external_id: '42',
                                                           error_class: 'ArgumentError', message: 'broken',
                                                           payload: { 'id' => 42 })
    end

    it 'counts the failure in the run' do
      tracker.guard('Catalog::Drugstore', 1) { raise 'x' }

      expect(tracker.run.reload.failed_count).to eq(1)
    end

    it 'keeps the phone of a client out of the stored data' do
      tracker.guard('Catalog::Drugstore', 1, { customer_phone_number: '380501112233' }) { raise 'x' }

      expect(tracker.run.failures.sole.payload).to eq('customer_phone_number' => '[masked]')
    end
  end

  describe '#finish!' do
    it 'closes a run without failures as succeeded' do
      tracker.finish!

      expect(tracker.run).to have_attributes(status: 'succeeded', finished_at: be_present)
    end

    it 'closes a run with a failed record as completed with failures' do
      tracker.guard('Catalog::Drugstore', 1) { raise 'x' }
      tracker.finish!

      expect(tracker.run.status).to eq('completed_with_failures')
    end

    it 'closes a run that lost a page as completed with failures, though no record failed' do
      tracker.page_failed!(2, RuntimeError.new('503'))
      tracker.finish!

      expect(tracker.run.status).to eq('completed_with_failures')
    end
  end

  describe '#processed!' do
    it 'adds to the count of processed records' do
      tracker.processed!
      tracker.processed!(3)

      expect(tracker.run.reload.processed_count).to eq(4)
    end
  end

  it 'keeps the cursor and the other progress together', :aggregate_failures do
    tracker.advance(3)
    tracker.update_progress('last_page' => 9)

    expect(tracker.run.reload.progress).to eq('mode' => 'full', 'cursor' => 3, 'last_page' => 9)
  end
end
