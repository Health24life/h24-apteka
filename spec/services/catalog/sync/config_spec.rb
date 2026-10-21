# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Config do
  subject(:config) { described_class.new }

  it 'has the defaults of the sync', :aggregate_failures do
    expect(config).to have_attributes(search_points: [], stale_run_after: 6.hours, stale_record_after: 1.day)
    expect(config.pull).to have_attributes(stash_ttl: 10.minutes, cooldown: 15.minutes, run_retention: 90.days)
  end

  it 'reads the search points from JSON, as the environment gives them' do
    config.configure { it.search_points = '[{"latitude": 50.4, "longitude": 30.5, "radius": 20000}]' }

    expect(config.search_points).to eq(
      [
        Pharmapoint::SearchPoint.new(
          latitude: 50.4,
          longitude: 30.5,
          radius: 20_000
        )
      ]
    )
  end

  it 'reads the periods of the pull as seconds and days', :aggregate_failures do
    config.configure { it.pull.update(stash_ttl: '60', cooldown: '120', run_retention: '30') }

    expect(config.pull).to have_attributes(stash_ttl: 1.minute, cooldown: 2.minutes, run_retention: 30.days)
  end

  it 'keeps the periods of the pull when they are given back their own defaults, as for an unset variable' do
    config.configure do |settings|
      pull = settings.pull
      pull.update(stash_ttl: pull.stash_ttl, cooldown: pull.cooldown, run_retention: pull.run_retention)
    end

    expect(config.pull).to have_attributes(stash_ttl: 10.minutes, cooldown: 15.minutes, run_retention: 90.days)
  end
end
