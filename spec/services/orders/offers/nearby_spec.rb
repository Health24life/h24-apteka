# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Offers::Nearby do
  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:goods) { create(:catalog_goods) }
  let(:location) { Catalog::Search::Location.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }
  let(:answers) { {} }

  before do
    ProviderLinking.link(provider, goods)
    stub_const('Orders::Offers::Adapters::BY_CODE', { 'pharmapoint' => fake_adapter })
  end

  # A provider that gives the answer the example put in `answers` under its code.
  def fake_adapter
    answers = self.answers
    Class.new do
      attr_reader :provider

      define_method(:initialize) { |provider:, **| @provider = provider }
      define_method(:nearby) { |*| answers.fetch(provider.code) }
    end
  end

  def drugstore(**) = create(:catalog_drugstore, **)

  def offer(drugstore_id, price: '100', distance: 1000, fulfilled: true, available: 2)
    line = Orders::Offers::Line.new(
      goods_id: goods.id,
      fulfilled:,
      price: BigDecimal(price),
      available_quantity: available
    )
    Orders::Offers::DrugstoreOffer.unknown(drugstore_id).with(distance:, open_now: true, lines: [ line ])
  end

  def call(**) = described_class.call(goods, location:, **)

  it 'lists the drugstores of the directory with the price of the SKU, the cheapest first', :aggregate_failures do
    near = drugstore
    far = drugstore
    answers['pharmapoint'] = [ offer(near.id, price: '120', distance: 500), offer(far.id, price: '90', distance: 4000) ]

    expect(call.map(&:drugstore)).to eq([ far, near ])
    expect(call.first).to have_attributes(price: BigDecimal('90'), available_quantity: 2, distance: 4000)
  end

  it 'sorts by distance when asked, an unknown distance last' do
    near = drugstore
    far = drugstore
    unknown = drugstore
    answers['pharmapoint'] = [
      offer(unknown.id, distance: nil),
      offer(far.id, distance: 4000),
      offer(near.id, distance: 500)
    ]

    expect(call(sort: 'distance').map(&:drugstore)).to eq([ near, far, unknown ])
  end

  it 'leaves out a drugstore without the SKU, with no data, hidden, withdrawn or missing from the directory' do
    shown = drugstore
    answers['pharmapoint'] = [
      offer(shown.id),
      offer(drugstore.id, fulfilled: false),
      Orders::Offers::DrugstoreOffer.unknown(drugstore.id),
      offer(drugstore(hidden: true).id),
      offer(drugstore(withdrawn: true).id),
      offer(nil)
    ]

    expect(call.map(&:drugstore)).to eq([ shown ])
  end

  it 'keeps only drugstores of the program «Доступні ліки» when asked' do
    member = drugstore(work_with_reimbursement: true)
    answers['pharmapoint'] = [ offer(member.id), offer(drugstore.id) ]

    expect(call(reimbursement: true).map(&:drugstore)).to eq([ member ])
  end

  context 'with a drugstore more than one provider answered for' do
    let(:shared) { drugstore }

    before do
      other = create(:provider, code: 'other')
      ProviderLinking.link(other, goods)
      stub_const('Orders::Offers::Adapters::BY_CODE', { 'pharmapoint' => fake_adapter, 'other' => fake_adapter })
      answers['pharmapoint'] = [ offer(shared.id, price: '120') ]
      answers['other'] = [ offer(shared.id, price: '90') ]
    end

    it 'lists it once, at its cheapest' do
      expect(call).to contain_exactly(have_attributes(drugstore: shared, price: BigDecimal('90')))
    end
  end

  describe '«Мої аптеки»' do
    let(:stores) { { mine: drugstore, cheap: drugstore, near: drugstore } }

    before do
      create(:favorite_drugstore, user_id: 42, drugstore: stores[:mine])
      create(:favorite_drugstore, user_id: 7, drugstore: stores[:cheap])
      answers['pharmapoint'] = [
        offer(stores[:near].id, price: '120', distance: 300),
        offer(stores[:cheap].id, price: '80', distance: 5000),
        offer(stores[:mine].id, price: '150', distance: 9000)
      ]
    end

    def listed(**) = call(**).map { stores.key(it.drugstore) }

    it 'puts the drugstores of the user first, then the rest by price' do
      expect(listed(user_id: 42)).to eq(%i[mine cheap near])
    end

    it 'puts them first when sorted by distance too' do
      expect(listed(user_id: 42, sort: 'distance')).to eq(%i[mine near cheap])
    end

    it 'marks the drugstores of the user' do
      expect(call(user_id: 42).map(&:favorite)).to eq([ true, false, false ])
    end

    it 'marks none and keeps the order of prices for a guest', :aggregate_failures do
      expect(listed).to eq(%i[cheap near mine])
      expect(call.map(&:favorite)).to all(be(false))
    end
  end

  it 'is an empty list when no drugstore around has the SKU' do
    answers['pharmapoint'] = []

    expect(call).to eq([])
  end

  describe 'a failure' do
    it 'is busy with the wait of the provider when it refused for its limit' do
      answers['pharmapoint'] = Orders::Offers::Failure.new(reason: :rate_limited, retry_after: 12)

      expect(call).to have_attributes(reason: :rate_limited, retry_after: 12)
    end

    it 'is unavailable when the provider did not answer' do
      answers['pharmapoint'] = Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil)

      expect(call).to have_attributes(reason: :unavailable)
    end

    it 'is unavailable when no enabled provider with an adapter knows the SKU' do
      provider.update!(active: false)

      expect(call).to have_attributes(reason: :unavailable)
    end
  end

  describe '.find_goods' do
    it 'finds a SKU shown in the catalog only', :aggregate_failures do
      expect(described_class.find_goods(goods.id)).to eq(goods)
      expect(described_class.find_goods(create(:catalog_goods, hidden: true).id)).to be_nil
      expect(described_class.find_goods(create(:catalog_goods, withdrawn: true).id)).to be_nil
      hidden_group = create(:catalog_goods_group, hidden: true)
      expect(described_class.find_goods(create(:catalog_goods, goods_group: hidden_group).id)).to be_nil
    end
  end
end
