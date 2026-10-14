# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Redirects::Cache do
  let(:goods) { create(:catalog_goods, slug: 'nurofen') }

  def ttl(slug) = described_class.redis.ttl(described_class.key('goods', slug))

  def lead_to_goods = have_attributes(type: 'Catalog::Goods', id: goods.id, manual: false)

  it 'holds an old slug as soon as the change is committed' do
    goods.update!(slug: 'nurofen-forte')

    expect(described_class.target('goods', 'nurofen')).to lead_to_goods
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

    expect(described_class.target('goods', 'staryi')).to be_nil
  end

  it 'drops the redirect of a slug the record takes back', :aggregate_failures do
    goods.update!(slug: 'nurofen-forte')
    goods.update!(slug: 'nurofen')

    expect(described_class.target('goods', 'nurofen')).to be_nil
    expect(described_class.target('goods', 'nurofen-forte')).to lead_to_goods
  end

  it 'keeps the kinds of pages apart' do
    goods.update!(slug: 'nurofen-forte')

    expect(described_class.target('category', 'nurofen')).to be_nil
  end

  it 'leads an old slug of one kind of page to a record of another kind' do
    category = create(:catalog_category)
    create(:seo_redirect, page_type: 'goods', slug: 'staryi', redirectable: category)

    expect(described_class.target('goods', 'staryi'))
      .to have_attributes(type: 'Catalog::Category', id: category.id, manual: false)
  end

  it 'refills itself from the table', :aggregate_failures do
    goods.update!(slug: 'nurofen-forte')
    create(:seo_redirect, slug: 'staryi', created_at: 4.months.ago)
    described_class.clear

    expect(described_class.rebuild).to eq(1)
    expect(described_class.target('goods', 'nurofen')).to lead_to_goods
  end

  it 'finds a redirect Redis lost in the table and caches it again', :aggregate_failures do
    goods.update!(slug: 'nurofen-forte')
    described_class.clear

    expect(described_class.target('goods', 'nurofen')).to lead_to_goods
    expect(described_class.redis.get(described_class.key('goods', 'nurofen'))).to eq("Catalog::Goods:#{goods.id}:0")
  end

  describe 'while Redis is unreachable' do
    before do
      %i[get set del].each { allow(described_class.redis).to receive(it).and_raise(Redis::CannotConnectError) }
      allow(Rails.error).to receive(:report)
    end

    it 'saves a slug change and answers from the table', :aggregate_failures do
      expect { goods.update!(slug: 'nurofen-forte') }.not_to raise_error
      expect(described_class.target('goods', 'nurofen')).to lead_to_goods
      expect(Rails.error).to have_received(:report).with(an_instance_of(Redis::CannotConnectError), handled: true)
                                                   .at_least(:once)
    end
  end

  it 'drops the cached redirects of a record that is gone' do
    goods.update!(slug: 'nurofen-forte')

    goods.destroy!

    expect(described_class.redis.get(described_class.key('goods', 'nurofen'))).to be_nil
  end

  it 'tells a redirect an editor set by hand', :aggregate_failures do
    category = create(:catalog_category)
    create(:seo_redirect, page_type: 'goods', slug: 'ruchna', redirectable: category, manual: true)

    expect(described_class.redis.get(described_class.key('goods', 'ruchna')))
      .to eq("Catalog::Category:#{category.id}:1")
    expect(described_class.target('goods', 'ruchna')).to have_attributes(manual: true)
  end

  it 'reads a value written before the flag as an automatic redirect' do
    described_class.redis.set(described_class.key('goods', 'stare'), 'Catalog::Goods:42')

    expect(described_class.target('goods', 'stare')).to have_attributes(type: 'Catalog::Goods', id: 42, manual: false)
  end
end
