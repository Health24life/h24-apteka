# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Search::Run do
  let(:location) { Catalog::Search::Location.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }
  let(:query) { Catalog::Search::Query.new(text: 'спазмалгон', page: 1, location:) }
  let(:first) { create(:provider, code: 'first') }
  let(:second) { create(:provider, code: 'second') }

  before { allow(Catalog::Sync::Pulls::EnqueueFound).to receive(:call).and_return({}) }

  def hit(provider, external_id)
    Catalog::Search::Hit.new(
      provider: provider.code,
      group_external_id: 'group',
      external_id:,
      name: external_id,
      release_form: nil,
      dosage: nil,
      pack: {},
      trade_name: nil,
      producer_name: nil,
      producer_country_code: nil,
      group_name: nil,
      is_recipe: false,
      is_strict_recipe: false,
      ready: false,
      id: nil,
      slug: nil
    )
  end

  def page(provider, *ids, total: 1, more: false, records: [ { 'id' => 'group' } ])
    Catalog::Search::ProviderPage.new(
      provider: provider.code,
      hits: ids.map { hit(provider, it) },
      per_page: 20,
      total_groups: total,
      has_more: more,
      records:
    )
  end

  def failure(provider, reason = :unavailable, retry_after = nil)
    Catalog::Search::Failure.new(provider: provider.code, reason:, retry_after:)
  end

  # Answers as a provider would; the block gets the query and the time left and returns a page or a failure.
  def adapter(provider, answer = nil, &block)
    answering = block || ->(*) { answer }
    instance_double(Pharmapoint::Search, provider:).tap do |adapter|
      allow(adapter).to receive(:call) { |asked, time_left:| answering.call(asked, time_left) }
    end
  end

  def run(*adapters, queries: [ query ], deadline: 4.0)
    described_class.call(queries, user_id: 7, config: search_config(deadline:), adapters:)
  end

  it 'lists the goods of every provider in the order of the providers, each in its own', :aggregate_failures do
    result = run(adapter(first, page(first, 'b', 'a', total: 3, more: true)), adapter(second, page(second, 'c'))).sole

    expect(result.goods.map { [ it.provider, it.external_id ] }).to eq([ %w[first b], %w[first a], %w[second c] ])
    expect(result).to have_attributes(
      query: 'спазмалгон',
      status: 'ok',
      page: 1,
      per_page: 40,
      total_groups: 4,
      has_more: true
    )
  end

  it 'answers with the providers that answered, keeping those that did not among its failures', :aggregate_failures do
    result = run(adapter(first, failure(first)), adapter(second, page(second, 'c'))).sole

    expect(result).to have_attributes(status: 'partial', failures: [ failure(first) ])
    expect(result.goods.map(&:external_id)).to eq(%w[c])
  end

  it 'is unavailable when no provider answered' do
    result = run(adapter(first, failure(first, :rate_limited, 12))).sole

    expect(result).to have_attributes(status: 'unavailable', goods: [], failures: [ failure(first, :rate_limited, 12) ])
  end

  it 'is busy, with the earliest wait, when every provider refused for its limit', :aggregate_failures do
    result = run(
      adapter(first, failure(first, :rate_limited, 30)),
      adapter(second, failure(second, :rate_limited, 12))
    ).sole

    expect(result).to have_attributes(busy?: true, retry_after: 12)
  end

  it 'is not busy when one of the providers is down for another reason' do
    result = run(adapter(first, failure(first, :rate_limited, 30)), adapter(second, failure(second))).sole

    expect(result.busy?).to be(false)
  end

  it 'is unavailable with no provider to ask' do
    expect(run.sole).to have_attributes(status: 'unavailable', failures: [])
  end

  it 'is an empty list, not a failure, when the providers found nothing' do
    expect(run(adapter(first, page(first, total: 0, records: []))).sole).to have_attributes(status: 'ok', goods: [])
  end

  it 'answers every query in its order' do
    other = query.with(text: 'цитрамон')
    answering = adapter(first) { |asked, _| page(first, asked.text) }

    expect(run(answering, queries: [ query, other ]).map(&:query)).to eq(%w[спазмалгон цитрамон])
  end

  it 'gives every provider only what is left of the time of the request', :aggregate_failures do
    slow = adapter(first) { sleep(0.2) && page(first, 'a') }
    later = adapter(second, page(second, 'b'))

    run(slow, later, deadline: 1.0)

    expect(slow).to have_received(:call).with(query, time_left: be_within(0.05).of(1.0))
    expect(later).to have_received(:call).with(query, time_left: be < 0.85)
  end

  it 'hands what each provider found to the sync to save', :aggregate_failures do
    run(adapter(first, page(first, 'a', records: [ { 'id' => 'g1' } ])), adapter(second, page(second, records: [])))

    expect(Catalog::Sync::Pulls::EnqueueFound).to have_received(:call)
      .with(provider: first, found: [ { 'id' => 'g1' } ], user_id: 7).once
    expect(Catalog::Sync::Pulls::EnqueueFound).to have_received(:call).once
  end

  it 'answers the same when the hand-off to the sync fails' do
    allow(Rails.cache).to receive(:write_multi).and_raise(Redis::CannotConnectError)
    allow(Catalog::Sync::Pulls::EnqueueFound).to receive(:call).and_call_original

    result = run(adapter(first, page(first, 'a', records: [ complete_goods_group ]))).sole

    expect(result).to have_attributes(status: 'ok', goods: [ have_attributes(external_id: 'a') ])
  end
end
