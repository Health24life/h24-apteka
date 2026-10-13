# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Redirects::Cache do
  let(:goods) { create(:catalog_goods, slug: 'nurofen') }

  def ttl(slug) = described_class.redis.ttl(described_class.key('Catalog::Goods', slug))

  it 'holds an old slug as soon as the change is committed' do
    goods.update!(slug: 'nurofen-forte')

    expect(described_class.target_id('Catalog::Goods', 'nurofen')).to eq(goods.id)
  end

  it 'keeps a redirect for the rest of its period' do
    goods.update!(slug: 'nurofen-forte')
    goods.seo_redirects.sole.tap { it.update_column(:created_at, 1.month.ago) } # rubocop:disable Rails/SkipsModelValidations
         .then { described_class.write(it) }

    expect(ttl('nurofen')).to be_within(60).of((2.months.from_now - Time.current).to_i)
  end

  it 'does not hold a redirect past its period' do
    redirect = create(:seo_redirect, slug: 'staryi', created_at: 4.months.ago)
    described_class.write(redirect)

    expect(described_class.target_id(redirect.redirectable_type, 'staryi')).to be_nil
  end

  it 'drops the redirect of a slug the record takes back', :aggregate_failures do
    goods.update!(slug: 'nurofen-forte')
    goods.update!(slug: 'nurofen')

    expect(described_class.target_id('Catalog::Goods', 'nurofen')).to be_nil
    expect(described_class.target_id('Catalog::Goods', 'nurofen-forte')).to eq(goods.id)
  end

  it 'keeps the kinds of records apart' do
    goods.update!(slug: 'nurofen-forte')

    expect(described_class.target_id('Catalog::Category', 'nurofen')).to be_nil
  end

  it 'refills itself from the table', :aggregate_failures do
    goods.update!(slug: 'nurofen-forte')
    create(:seo_redirect, slug: 'staryi', created_at: 4.months.ago)
    described_class.clear

    expect(described_class.rebuild).to eq(1)
    expect(described_class.target_id('Catalog::Goods', 'nurofen')).to eq(goods.id)
  end

  it 'finds a redirect Redis lost in the table and caches it again', :aggregate_failures do
    goods.update!(slug: 'nurofen-forte')
    described_class.clear

    expect(described_class.target_id('Catalog::Goods', 'nurofen')).to eq(goods.id)
    expect(described_class.redis.get(described_class.key('Catalog::Goods', 'nurofen'))).to eq(goods.id.to_s)
  end

  describe 'while Redis is unreachable' do
    before do
      %i[get set del].each { allow(described_class.redis).to receive(it).and_raise(Redis::CannotConnectError) }
      allow(Rails.error).to receive(:report)
    end

    it 'saves a slug change and answers from the table', :aggregate_failures do
      expect { goods.update!(slug: 'nurofen-forte') }.not_to raise_error
      expect(described_class.target_id('Catalog::Goods', 'nurofen')).to eq(goods.id)
      expect(Rails.error).to have_received(:report).with(an_instance_of(Redis::CannotConnectError), handled: true)
                                                   .at_least(:once)
    end
  end

  it 'drops the cached redirects of a record that is gone' do
    goods.update!(slug: 'nurofen-forte')

    goods.destroy!

    expect(described_class.redis.get(described_class.key('Catalog::Goods', 'nurofen'))).to be_nil
  end
end
