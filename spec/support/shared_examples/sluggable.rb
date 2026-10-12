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

  it 'refuses a manual change' do
    record = create(factory)

    expect { record.update(slug: 'other') }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end

  it 'refuses a slug changed by writing the attribute directly' do
    record = create(factory)
    record[:slug] = 'other'

    expect(record).not_to be_valid
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
