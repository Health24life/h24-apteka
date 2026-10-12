# frozen_string_literal: true

RSpec.shared_examples 'a translatable catalog record' do |factory|
  it 'requires the Ukrainian name' do
    record = build(factory, name_uk: nil)

    expect(record).not_to be_valid
  end

  it 'treats a whitespace-only Ukrainian name as missing' do
    expect(build(factory, name_uk: '   ')).not_to be_valid
  end

  it 'refuses a name assigned through an accessor of another locale', :aggregate_failures do
    record = build(factory, name_uk: 'Назва')
    record.public_send(:name_en=, 'Tablets')

    expect(record).not_to be_valid
    expect(record.errors[:name]).to be_present
  end

  it 'shows the Ukrainian name when the interface language has no translation' do
    record = create(factory, name_uk: 'Назва')

    expect(I18n.with_locale(:en) { record.reload.name }).to eq('Назва')
  end

  it 'stores the Ukrainian name in the database' do
    record = create(factory, name_uk: 'Назва')

    expect(stored_names(record)).to eq('uk' => 'Назва')
  end

  it 'refuses a name written in a locale outside the catalog languages', :aggregate_failures do
    record = create(factory, name_uk: 'Назва')

    expect { I18n.with_locale(:en) { record.update!(name: 'Tablets') } }.to raise_error(ActiveRecord::RecordInvalid)
    expect(stored_names(record)).to eq('uk' => 'Назва')
  end

  it 'reports a name in a locale outside the catalog languages before writing anything', :aggregate_failures do
    record = I18n.with_locale(:en) { build(factory, name: 'Tablets') }

    expect(record).not_to be_valid
    expect(record.errors[:name]).to be_present
    expect { record.save }.not_to change(record.class, :count)
  end

  it 'saves under another interface language after the record was read for a cache key' do
    record = create(factory)

    expect(I18n.with_locale(:en) { record.cache_key && record.save }).to be(true)
  end

  it 'keeps a Ukrainian rename valid' do
    record = create(factory, name_uk: 'Назва')

    expect { record.update!(name_uk: 'Нова назва') }.not_to raise_error
  end
end
