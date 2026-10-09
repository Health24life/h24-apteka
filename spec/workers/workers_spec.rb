# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'the workers of the partner integration' do # rubocop:disable RSpec/DescribeClass
  workers = [ Catalog::Sync::StartWorker, Catalog::Sync::StepWorker, Catalog::Sync::PullWorker,
              Pharmapoint::LogCleanupWorker ]

  workers.each do |worker|
    describe worker do
      it 'has valid sidekiq options' do
        expect(worker).to have_valid_sidekiq_options
      end

      it 'asks for a unique lock' do
        expect(worker.get_sidekiq_options['lock']).to be_present
      end
    end
  end

  it 'queues a step once, but lets it queue itself again from inside' do
    expect(Catalog::Sync::StepWorker.get_sidekiq_options['lock']).to eq(:until_and_while_executing)
  end

  describe 'a start' do
    before { create(:provider, code: 'pharmapoint') }

    it 'is dropped while the same kind of start is waiting', :aggregate_failures do
      results = with_unique_jobs { Array.new(2) { Catalog::Sync::StartWorker.perform_async('categories') } }

      expect(results.compact.size).to eq(1)
      expect(Catalog::Sync::StartWorker.jobs.size).to eq(1)
    end

    it 'is not held against a start of another kind' do
      results = with_unique_jobs { %w[categories drugstores].map { Catalog::Sync::StartWorker.perform_async(it) } }

      expect(results.compact.size).to eq(2)
    end
  end

  describe 'a step' do
    it 'is queued once for a run and a cursor', :aggregate_failures do
      results = with_unique_jobs { Array.new(2) { Catalog::Sync::StepWorker.perform_async(1, 2) } }

      expect(results.compact.size).to eq(1)
      expect(Catalog::Sync::StepWorker.jobs.size).to eq(1)
    end
  end

  describe Pharmapoint::LogCleanupWorker do
    it 'is queued once while a cleanup waits' do
      results = with_unique_jobs { Array.new(2) { described_class.perform_async } }

      expect(results.compact.size).to eq(1)
    end
  end
end
