# spec/models/catalog/atc_class_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::AtcClass do
  it { is_expected.to validate_presence_of(:atc_code) }

  it 'does not require a name', :aggregate_failures do
    atc = build(:catalog_atc_class)

    expect(atc).to be_valid
    expect(atc.name_uk).to be_nil
  end

  it 'stores a Ukrainian name when given' do
    atc = create(:catalog_atc_class, name_uk: 'Нервова система')

    expect(atc.reload.name_uk).to eq('Нервова система')
  end

  it 'forms a tree', :aggregate_failures do
    root = create(:catalog_atc_class, atc_code: 'N')
    child = create(:catalog_atc_class, atc_code: 'N02', parent: root)

    expect(described_class.roots).to contain_exactly(root)
    expect(root.children).to contain_exactly(child)
  end

  it 'refuses a class as its own parent, in the model and in the database', :aggregate_failures do
    atc = create(:catalog_atc_class)
    atc.parent = atc

    expect(atc).not_to be_valid
    expect { atc.update_column(:parent_id, atc.id) }.to raise_error(ActiveRecord::StatementInvalid) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'refuses to delete a class that has children' do
    root = create(:catalog_atc_class)
    create(:catalog_atc_class, parent: root)

    expect { root.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

# == Schema Information
#
# Table name: catalog_atc_classes
#
#  id         :bigint           not null, primary key
#  atc_code   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#
# Indexes
#
#  index_catalog_atc_classes_on_parent_id  (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => catalog_atc_classes.id)
#
# Check Constraints
#
#  catalog_atc_classes_parent_check  (parent_id IS NULL OR parent_id <> id)
#
