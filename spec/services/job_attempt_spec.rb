# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobAttempt do
  def attempt_for(job)
    seen = nil
    described_class.new.call(nil, job, 'default') { seen = described_class.current }
    seen
  end

  it 'is the first attempt for a job that has not failed yet' do
    expect(attempt_for({})).to eq(1)
  end

  it 'counts the first retry as the second attempt', :aggregate_failures do
    expect(attempt_for({ 'retry_count' => 0 })).to eq(2)
    expect(attempt_for({ 'retry_count' => 2 })).to eq(4)
  end

  it 'forgets the attempt once the job is done' do
    attempt_for({ 'retry_count' => 3 })

    expect(described_class.current).to eq(1)
  end

  it 'forgets the attempt when the job raises', :aggregate_failures do
    expect { described_class.new.call(nil, { 'retry_count' => 1 }, 'default') { raise 'boom' } }.to raise_error('boom')

    expect(described_class.current).to eq(1)
  end
end
