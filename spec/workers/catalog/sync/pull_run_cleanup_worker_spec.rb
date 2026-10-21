# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::PullRunCleanupWorker do
  it 'removes the fetches that outlived their period' do
    create(:sync_run, :succeeded, started_at: 100.days.ago, progress: { 'mode' => 'pull' })

    expect { described_class.new.perform }.to change(SyncRun, :count).from(1).to(0)
  end
end
