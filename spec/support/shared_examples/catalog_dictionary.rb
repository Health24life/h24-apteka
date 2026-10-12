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
end
