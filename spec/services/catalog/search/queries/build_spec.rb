# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Search::Queries::Build do
  let(:config) do
    search_config(
      max_queries: 1,
      location: {
        latitude: 50.4501,
        longitude: 30.5234,
        radius: 25_000,
        max_radius: 50_000
      }
    )
  end

  def build(queries) = described_class.call(queries, config:)

  def refused(queries)
    build(queries)
  rescue Catalog::Search::Invalid => e
    e.code
  end

  it 'reads a query with its text squeezed, the first page and the configured place' do
    expect(build([ { 'text' => '  спазмалгон   форте ' } ]).sole).to have_attributes(
      text: 'спазмалгон форте',
      page: 1,
      location: Catalog::Search::Location.new(latitude: 50.45, longitude: 30.52, radius: 25_000)
    )
  end

  it 'reads the page and the place the front sent, rounding the coordinates' do
    query = build(
      [
        {
          'text' => 'спазмалгон',
          'page' => 2,
          'location' => { 'latitude' => 49.83968, 'longitude' => 24.02972, 'radius' => 5000 }
        }
      ]
    ).sole

    expect(query).to have_attributes(
      page: 2,
      location: Catalog::Search::Location.new(
        latitude: 49.84, longitude: 24.03, radius: 5000
      )
    )
  end

  it 'takes the configured radius when the front sent coordinates only' do
    query = build([ { 'text' => 'спазмалгон', 'location' => { 'latitude' => 49.84, 'longitude' => 24.03 } } ]).sole

    expect(query.location.radius).to eq(25_000)
  end

  it 'refuses queries that are not an array of one to the allowed number', :aggregate_failures do
    [ nil, 'спазмалгон', [], [ { 'text' => 'спазмалгон' } ] * 2, [ 'спазмалгон' ] ].each do |queries|
      expect(refused(queries)).to eq(:invalid_search_queries)
    end
  end

  it 'refuses a text shorter than 3 or longer than 100 characters after squeezing', :aggregate_failures do
    [ '  ab  ', 'a' * 101, nil, 42 ].each { expect(refused([ { 'text' => it } ])).to eq(:invalid_search_text) }
  end

  it 'refuses a page that is not a whole number from 1 to 50', :aggregate_failures do
    [ 0, 51, '2', 1.5 ].each do |page|
      expect(refused([ { 'text' => 'спазмалгон', 'page' => page } ])).to eq(:invalid_search_page)
    end
  end

  it 'refuses a place it cannot search around', :aggregate_failures do
    [
      'Київ',
      { 'latitude' => 50.45 },
      { 'longitude' => 30.52 },
      { 'latitude' => 91, 'longitude' => 30.52 },
      { 'latitude' => 50.45, 'longitude' => '30.52' },
      { 'radius' => 0 },
      { 'radius' => 50_001 },
      { 'radius' => 1000.5 }
    ].each { expect(refused([ { 'text' => 'спазмалгон', 'location' => it } ])).to eq(:invalid_search_location) }
  end
end
