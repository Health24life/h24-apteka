# frozen_string_literal: true

RSpec.shared_examples 'a catalog dictionary' do |factory|
  it_behaves_like 'a translatable catalog record', factory

  it 'is valid with a Ukrainian name' do
    expect(build(factory)).to be_valid
  end

  it 'can be linked to a provider' do
    record = create(factory)
    link = create(:provider_link, linkable: record)

    expect(record.provider_ref(link.provider)).to eq(link.external_id)
  end

  it 'refuses to delete a record that has a provider link' do
    record = create(factory)
    create(:provider_link, linkable: record)

    expect { record.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  it 'refuses a translation row for the same locale twice, at the database level' do
    record = create(factory)
    base = record.class.table_name.singularize
    duplicate = "INSERT INTO #{base}_translations (#{base}_id, locale, name, created_at, updated_at) " \
                "VALUES (#{record.id}, 'uk', 'Дубль', now(), now())"

    expect { ActiveRecord::Base.connection.execute(duplicate) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
