# frozen_string_literal: true

RSpec.shared_examples 'a sluggable catalog record' do |factory|
  it 'generates the slug from the Ukrainian name on creation' do
    expect(create(factory, name_uk: 'Знеболювальні').slug).to eq('zneboliuvalni')
  end

  it 'adds a numeric suffix when the slug is taken' do
    create(factory, name_uk: 'Знеболювальні')

    expect(create(factory, name_uk: 'Знеболювальні').slug).to eq('zneboliuvalni-2')
  end

  it 'keeps the slug when the record is renamed' do
    record = create(factory, name_uk: 'Знеболювальні')

    record.update!(name_uk: 'Анальгетики')

    expect(record.reload.slug).to eq('zneboliuvalni')
  end

  it 'leaves the old slug redirecting to the record after an explicit change', :aggregate_failures do
    record = create(factory, name_uk: 'Знеболювальні')

    record.update!(slug: 'vid-boliu')

    expect(record.reload.slug).to eq('vid-boliu')
    expect(record.seo_redirects.pluck(:slug)).to eq([ 'zneboliuvalni' ])
  end

  it 'points every old slug at the current one after several changes' do
    record = create(factory, slug: 'a')

    record.update!(slug: 'b')
    record.update!(slug: 'c')

    expect(record.seo_redirects.pluck(:slug)).to contain_exactly('a', 'b')
  end

  it 'drops the redirect from a slug the record takes back', :aggregate_failures do
    record = create(factory, slug: 'a')

    record.update!(slug: 'b')
    record.update!(slug: 'a')

    expect(record.seo_redirects.pluck(:slug)).to eq([ 'b' ])
  end

  it 'refuses a slug that redirects to another record of the same kind', :aggregate_failures do
    other = create(factory, slug: 'nurofen')
    other.update!(slug: 'nurofen-forte')
    record = create(factory)

    expect(record.update(slug: 'nurofen')).to be(false)
    expect(record.errors.details[:slug]).to include(error: :taken)
  end

  it 'refuses a slug of its kind of page that redirects to a record of another kind', :aggregate_failures do
    record = create(factory)
    other = create(record.is_a?(Catalog::Goods) ? :catalog_category : :catalog_goods)
    create(:seo_redirect, page_type: Seo::Redirect.page_type_for(record.class), slug: 'staryi', redirectable: other)

    expect(record.update(slug: 'staryi')).to be(false)
    expect(record.errors.details[:slug]).to include(error: :taken)
  end

  it 'refuses such a slug given on creation' do
    create(factory, slug: 'nurofen').update!(slug: 'nurofen-forte')

    expect(build(factory, slug: 'nurofen')).not_to be_valid
  end

  it 'gives a new record a suffix instead of a slug that redirects elsewhere' do
    create(factory, name_uk: 'Знеболювальні').update!(slug: 'vid-boliu')

    expect(create(factory, name_uk: 'Знеболювальні').slug).to eq('zneboliuvalni-2')
  end

  it 'drops its redirects with the record' do
    record = create(factory, slug: 'a')
    record.update!(slug: 'b')

    expect { record.destroy! }.to change(Seo::Redirect, :count).by(-1)
  end

  it 'falls back to a fixed word for a name without letters' do
    expect(create(factory, name_uk: '!!!').slug).to eq('item')
  end

  it 'generates a valid slug from a name that contains an underscore' do
    expect(create(factory, name_uk: 'Вітамін_С').slug).to eq('vitamin-s')
  end

  it 'refuses a malformed slug in validation' do
    expect(build(factory).tap { it.slug = 'Bad Slug' }).not_to be_valid
  end

  it 'refuses a duplicate slug at the database level' do
    record = create(factory)
    other = create(factory)

    expect { other.update_column(:slug, record.slug) }.to raise_error(ActiveRecord::RecordNotUnique) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'refuses a malformed slug at the database level' do
    record = create(factory)

    expect { record.update_column(:slug, 'Bad_Slug') } # rubocop:disable Rails/SkipsModelValidations
      .to raise_error(ActiveRecord::StatementInvalid, /#{record.class.table_name}_slug_check/)
  end

  it 'refuses a slug longer than the limit at the database level' do
    record = create(factory)

    expect { record.update_column(:slug, 'a' * (Catalog::Sluggable::MAX_LENGTH + 1)) } # rubocop:disable Rails/SkipsModelValidations
      .to raise_error(ActiveRecord::StatementInvalid, /#{record.class.table_name}_slug_check/)
  end
end
