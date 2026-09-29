# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Provider do
  subject(:provider) { build(:provider) }

  it { is_expected.to be_valid }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_uniqueness_of(:code) }

  it 'accepts only snake_case codes', :aggregate_failures do
    expect(build(:provider, code: 'pharmapoint')).to be_valid
    expect(build(:provider, code: 'Pharma Point')).not_to be_valid
    expect(build(:provider, code: '1pharma')).not_to be_valid
  end

  it 'accepts only known kinds', :aggregate_failures do
    expect(build(:provider, kind: 'own')).to be_valid
    expect(build(:provider, kind: 'partner')).not_to be_valid
  end

  it 'keeps the code fixed once saved' do
    saved = create(:provider, code: 'stable')

    expect { saved.update(code: 'changed') }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end

  it 'refuses to store a kind outside the known list at the database level' do
    provider = create(:provider)

    expect { provider.update_column(:kind, 'partner') } # rubocop:disable Rails/SkipsModelValidations
      .to raise_error(ActiveRecord::StatementInvalid)
  end

  describe '.enabled' do
    it 'returns only active providers' do
      active = create(:provider)
      create(:provider, active: false)

      expect(described_class.enabled).to contain_exactly(active)
    end
  end
end

# == Schema Information
#
# Table name: providers
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  code              :string           not null
#  kind              :string           not null
#  name              :string           not null
#  supports_delivery :boolean          default(FALSE), not null
#  supports_e_recipe :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_providers_on_code  (code) UNIQUE
#
