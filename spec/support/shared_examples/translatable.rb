# frozen_string_literal: true

RSpec.shared_examples 'a translatable catalog record' do |factory|
  it 'requires the Ukrainian name' do
    record = build(factory, name_uk: nil)

    expect(record).not_to be_valid
  end

  it 'treats a whitespace-only Ukrainian name as missing' do
    expect(build(factory, name_uk: '   ')).not_to be_valid
  end

  it 'stores names in Ukrainian only', :aggregate_failures do
    record = build(factory, name_uk: 'Назва')

    expect(record).to respond_to(:name_uk)
    expect(record).not_to respond_to(:name_en)
    expect(record).not_to respond_to(:name_ru)
  end

  it 'shows the Ukrainian name when the interface language has no translation' do
    record = create(factory, name_uk: 'Назва')

    expect(I18n.with_locale(:en) { record.reload.name }).to eq('Назва')
  end

  it 'keeps the name in a translations row of its own table' do
    record = create(factory, name_uk: 'Назва')
    table = record.class.translation_class.table_name
    count = ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{table} WHERE locale = 'uk'")

    expect(count).to eq(1)
  end

  it 'refuses a name written in a locale outside the catalog languages', :aggregate_failures do
    record = create(factory, name_uk: 'Назва')

    expect { I18n.with_locale(:en) { record.update!(name: 'Tablets') } }.to raise_error(ActiveRecord::RecordInvalid)
    expect(record.class.translation_class.where(locale: 'en')).to be_empty
  end

  it 'reports a name in a locale outside the catalog languages before writing anything', :aggregate_failures do
    record = I18n.with_locale(:en) { build(factory, name: 'Tablets') }

    expect(record).not_to be_valid
    expect(record.errors[:name]).to be_present
    expect { record.save }.not_to change(record.class, :count)
  end

  it 'refuses a translation row outside the catalog languages at the database level' do
    record = create(factory)

    expect { insert_translation_row(record, locale: 'en') }
      .to raise_error(ActiveRecord::StatementInvalid, /locale_check/)
  end

  it 'keeps a Ukrainian rename valid' do
    record = create(factory, name_uk: 'Назва')

    expect { record.update!(name_uk: 'Нова назва') }.not_to raise_error
  end
end
