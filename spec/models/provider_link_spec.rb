# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProviderLink do
  subject(:link) { build(:provider_link) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:provider) }
  it { is_expected.to validate_presence_of(:external_id) }
  it { is_expected.to validate_presence_of(:synced_at) }

  it 'accepts only catalog types as linkable' do
    expect(build(:provider_link, linkable_type: 'Provider')).not_to be_valid
  end

  it 'refuses a repeated external id of one provider for the same kind of record' do
    first = create(:provider_link)
    other_brand = create(:catalog_drugstore_brand)

    duplicate = build(:provider_link, provider: first.provider, linkable: other_brand, external_id: first.external_id)

    expect(duplicate).not_to be_valid
  end

  it 'refuses a second link of one provider to the same record' do
    first = create(:provider_link)

    duplicate = build(:provider_link, provider: first.provider, linkable: first.linkable)

    expect(duplicate).not_to be_valid
  end

  describe 'database level, bypassing validations' do
    let(:first) { create(:provider_link) }
    let(:now) { Time.current }
    let(:row) do
      { provider_id: first.provider_id, linkable_type: 'Catalog::DrugstoreBrand', attrs: {}, synced_at: now,
        created_at: now, updated_at: now }
    end

    it 'refuses a repeated external id of one provider' do
      other = row.merge(linkable_id: create(:catalog_drugstore_brand).id, external_id: first.external_id)

      expect { described_class.insert_all!([ other ]) }.to raise_error(ActiveRecord::RecordNotUnique) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'refuses a second link of one provider to the same record' do
      other = row.merge(linkable_id: first.linkable_id, external_id: 'another')

      expect { described_class.insert_all!([ other ]) }.to raise_error(ActiveRecord::RecordNotUnique) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  it 'lets two providers link the same record, keeping one record with two links' do
    brand = create(:catalog_drugstore_brand)
    create(:provider_link, linkable: brand)
    create(:provider_link, linkable: brand)

    expect(brand.reload.provider_links.count).to eq(2)
  end

  it 'lets different providers reuse one external id', :aggregate_failures do
    first = create(:provider_link, external_id: '42')

    expect(build(:provider_link, external_id: '42')).to be_valid
    expect(first.provider).not_to eq(build(:provider_link).provider)
  end
end

# == Schema Information
#
# Table name: provider_links
#
#  id            :bigint           not null, primary key
#  attrs         :jsonb            not null
#  linkable_type :string           not null
#  synced_at     :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  external_id   :string           not null
#  linkable_id   :bigint           not null
#  provider_id   :bigint           not null
#
# Indexes
#
#  index_provider_links_on_linkable              (linkable_type,linkable_id)
#  index_provider_links_on_provider_external_id  (provider_id,linkable_type,external_id) UNIQUE
#  index_provider_links_on_provider_linkable     (provider_id,linkable_type,linkable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (provider_id => providers.id)
#
