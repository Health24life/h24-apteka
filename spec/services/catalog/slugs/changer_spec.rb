# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Slugs::Changer do
  let(:goods) { create(:catalog_goods, slug: 'nurofen') }

  it 'checks a new slug without saving it', :aggregate_failures do
    expect(described_class.check(record: goods, slug: ' nurofen-forte ')).to have_attributes(status: :valid, errors: [])
    expect(goods.reload.slug).to eq('nurofen')
    expect(Seo::Redirect.count).to eq(0)
  end

  it 'changes the slug and leaves a redirect from the old one', :aggregate_failures do
    expect(described_class.call(record: goods, slug: 'nurofen-forte').status).to eq(:changed)
    expect(goods.reload.slug).to eq('nurofen-forte')
    expect(goods.seo_redirects.pluck(:slug)).to eq([ 'nurofen' ])
  end

  it 'refuses a slug in another format' do
    expect(described_class.call(record: goods, slug: 'Нурофен Форте'))
      .to have_attributes(status: :invalid, errors: [ a_string_including('малі латинські літери') ])
  end

  it 'refuses a slug another SKU has' do
    create(:catalog_goods, slug: 'ibuprofen')

    expect(described_class.call(record: goods, slug: 'ibuprofen').errors.sole).to end_with('уже має інша сторінка')
  end

  it 'refuses a slug a redirect holds for another page' do
    create(:catalog_goods, slug: 'aspirin').update!(slug: 'aspirin-500')

    expect(described_class.check(record: goods, slug: 'aspirin').errors.sole)
      .to include('закріплена за іншою сторінкою')
  end

  it 'lets a record take back a slug of its own', :aggregate_failures do
    goods.update!(slug: 'nurofen-forte')

    expect(described_class.call(record: goods, slug: 'nurofen').status).to eq(:changed)
    expect(goods.seo_redirects.pluck(:slug)).to eq([ 'nurofen-forte' ])
  end

  it 'leaves the same slug alone' do
    expect(described_class.call(record: goods, slug: 'nurofen').status).to eq(:unchanged)
  end
end
