# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Drugstore do
  subject(:drugstore) { build(:catalog_drugstore) }

  it { is_expected.to be_valid }
  it { is_expected.to validate_presence_of(:drugstore_legal_entity_name) }
  it { is_expected.to validate_presence_of(:drugstore_legal_entity_code) }

  describe 'legal entity code' do
    it 'is stored as a string, keeping the leading zero' do
      expect(create(:catalog_drugstore, drugstore_legal_entity_code: '01234567').reload.drugstore_legal_entity_code)
        .to eq('01234567')
    end

    it 'accepts eight digits and ten digits for a sole proprietor', :aggregate_failures do
      expect(build(:catalog_drugstore, drugstore_legal_entity_code: '12345678')).to be_valid
      expect(build(:catalog_drugstore, drugstore_legal_entity_code: '0123456789')).to be_valid
    end

    it 'refuses other lengths and non-digits', :aggregate_failures do
      %w[123456789 1234567 12345678901 1234567A].each do |code|
        expect(build(:catalog_drugstore, drugstore_legal_entity_code: code)).not_to be_valid
      end
    end

    it 'is refused by the database as well' do
      drugstore = create(:catalog_drugstore)

      update = -> { drugstore.update_column(:drugstore_legal_entity_code, '123456789') } # rubocop:disable Rails/SkipsModelValidations

      expect(&update).to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe 'working hours' do
    it 'are valid as an empty list and invalid when missing', :aggregate_failures do
      expect(build(:catalog_drugstore, week_working_hours: [])).to be_valid
      expect(build(:catalog_drugstore, week_working_hours: nil)).not_to be_valid
    end

    it 'refuse six days and accept an unusual day format', :aggregate_failures do
      expect(build(:catalog_drugstore, week_working_hours: [ '08:00-21:00' ] * 6)).not_to be_valid
      expect(build(:catalog_drugstore, week_working_hours: ([ '08:00-21:00' ] * 6) + [ 'за домовленістю' ])).to be_valid
    end

    it 'are refused by the database when the shape is wrong' do
      drugstore = create(:catalog_drugstore)

      update = -> { drugstore.update_column(:week_working_hours, [ '08:00-21:00' ] * 6) } # rubocop:disable Rails/SkipsModelValidations

      expect(&update).to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  it 'takes the reimbursement flag and the three status flags off by default', :aggregate_failures do
    expect(create(:catalog_drugstore)).to have_attributes(work_with_reimbursement: false, withdrawn: false,
                                                          hidden: false, incomplete: false)
  end

  it 'keeps the withdrawn, hidden and incomplete flags independent' do
    drugstore = create(:catalog_drugstore, incomplete: true)

    drugstore.update!(hidden: true)

    expect(drugstore.reload).to have_attributes(incomplete: true, hidden: true, withdrawn: false)
  end

  it 'is valid without a brand, and with one', :aggregate_failures do
    expect(build(:catalog_drugstore, brand: nil)).to be_valid
    expect(build(:catalog_drugstore, brand: create(:catalog_drugstore_brand))).to be_valid
  end

  it 'is valid without an address' do
    expect(create(:catalog_drugstore).address).to be_nil
  end

  it 'refuses to delete a brand that has drugstores' do
    brand = create(:catalog_drugstore_brand)
    create(:catalog_drugstore, brand:)

    expect { brand.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  it 'refuses to delete a drugstore that has a provider link' do
    link = create(:provider_link, linkable: create(:catalog_drugstore))

    expect { link.linkable.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  it 'stays one record when two providers serve it' do
    drugstore = create(:catalog_drugstore)
    create(:provider_link, linkable: drugstore)
    create(:provider_link, linkable: drugstore)

    expect(drugstore.reload.provider_links.count).to eq(2)
  end

  it 'removes its address together with itself' do
    drugstore = create(:catalog_drugstore)
    create(:catalog_drugstore_address, drugstore:)

    expect { drugstore.destroy }.to change(Catalog::DrugstoreAddress, :count).by(-1)
  end
end

# == Schema Information
#
# Table name: catalog_drugstores
#
#  id                          :bigint           not null, primary key
#  drugstore_legal_entity_code :string           not null
#  drugstore_legal_entity_name :string           not null
#  email                       :string
#  hidden                      :boolean          default(FALSE), not null
#  incomplete                  :boolean          default(FALSE), not null
#  mobile_phone                :string
#  name                        :string
#  phone                       :string
#  week_working_hours          :jsonb            not null
#  withdrawn                   :boolean          default(FALSE), not null
#  work_with_reimbursement     :boolean          default(FALSE), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  brand_id                    :bigint
#  ext_drugstore_id            :string
#
# Indexes
#
#  index_catalog_drugstores_on_brand_id  (brand_id)
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => catalog_drugstore_brands.id)
#
# Check Constraints
#
#  catalog_drugstores_legal_entity_code_check  (drugstore_legal_entity_code::text ~ '^[0-9]{8}([0-9]{2})?$'::text)
#  catalog_drugstores_week_hours_check         (jsonb_array_length(week_working_hours) = ANY (ARRAY[0, 7]))
#
