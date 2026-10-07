# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::TopList do
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:ids) { Array.new(4) { |index| format('%032x', index + 1) } }
  let(:file) { Tempfile.new('top-list') }

  def list(*lines)
    file.write(lines.join("\n"))
    file.flush
    described_class.call(file.path)
  end

  before { use_pharmapoint_config }

  after { file.close! }

  it 'queues every group of the list', :aggregate_failures do
    result = list(*ids)

    expect(result).to have_attributes(enqueued: 4, present: 0, failed: 0, messages: [])
    expect(Catalog::Sync::PullWorker.jobs.size).to eq(4)
  end

  it 'counts the groups the catalog already has apart from the queued ones', :aggregate_failures do
    group = create(:catalog_goods_group)
    Provider::Link.create!(provider:, linkable: group, external_id: ids.first, synced_at: 1.hour.ago)

    result = list(*ids)

    expect(result).to have_attributes(enqueued: 3, present: 1)
  end

  it 'skips an empty line and a line that is not an id with a message, and goes on', :aggregate_failures do
    result = list(ids.first, '', 'paracetamol', ids.second)

    expect(result).to have_attributes(enqueued: 2, failed: 2)
    expect(result.messages).to eq([ 'line 2: empty line, skipped',
                                    "line 3: 'paracetamol' is not a goods group id, skipped" ])
  end

  it 'queues a group once when the list names it twice' do
    result = with_unique_jobs { list(ids.first, ids.first) }

    expect(result).to have_attributes(enqueued: 1, present: 1)
  end
end
