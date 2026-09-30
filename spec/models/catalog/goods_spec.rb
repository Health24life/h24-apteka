# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Goods do
  it_behaves_like 'a translatable catalog record', :catalog_goods

  it 'keeps translations in the explicitly named table' do
    goods = create(:catalog_goods, name_uk: 'Аспірин')

    count = ActiveRecord::Base.connection.select_value(
      "SELECT count(*) FROM catalog_goods_translations WHERE catalog_goods_id = #{goods.id}"
    )

    expect(count).to eq(1)
  end

  it 'needs a goods group' do
    expect(build(:catalog_goods, goods_group: nil)).not_to be_valid
  end

  it 'starts with the prescription and hiding flags off', :aggregate_failures do
    goods = create(:catalog_goods)

    expect(goods).to have_attributes(is_recipe: false, is_strict_recipe: false, in_medication_program: false,
                                     withdrawn: false, hidden: false, image_paths: [])
  end

  it 'keeps the withdrawn and hidden flags independent' do
    goods = create(:catalog_goods, hidden: true)

    expect(goods.reload).to have_attributes(hidden: true, withdrawn: false)
  end

  it 'reaches producer, trade name and ATC class through the group', :aggregate_failures do
    producer = create(:catalog_producer)
    group = create(:catalog_goods_group, producer:)
    goods = create(:catalog_goods, goods_group: group)

    expect(goods.producer).to eq(producer)
    expect(goods.goods_name).to be_nil
  end

  it 'links the four dictionaries', :aggregate_failures do
    goods = create(:catalog_goods, form: create(:catalog_goods_form), measure: create(:catalog_goods_measure),
                                   price_group: create(:catalog_goods_price_group),
                                   temperature_mode: create(:catalog_goods_temperature_mode))

    expect(goods.reload.form).to be_present
    expect(goods.temperature_mode).to be_present
  end

  it 'links the five restrictions' do
    restriction = create(:catalog_goods_restriction)
    goods = create(:catalog_goods, adult_restriction: restriction, child_restriction: restriction,
                                   diabetic_restriction: restriction, driver_restriction: restriction,
                                   pregnant_and_lactating_restriction: restriction)

    expect(goods.reload.pregnant_and_lactating_restriction).to eq(restriction)
  end

  it 'refers to a core INN without a foreign key' do
    inn = create(:h24_core_inn)

    expect(create(:catalog_goods, core_inn_id: inn.id).core_inn).to eq(inn)
  end

  describe 'pack quantities' do
    it 'accept zero and positive whole numbers and nil' do
      expect(build(:catalog_goods, pack_quantity_in_pack: 0, pack_quantity_unit_in_pack: 10,
                                   pack_quantity_in_unit: nil))
        .to be_valid
    end

    it 'refuse negatives and fractions in the model', :aggregate_failures do
      expect(build(:catalog_goods, pack_quantity_in_pack: -1)).not_to be_valid
      expect(build(:catalog_goods, pack_quantity_in_unit: 1.5)).not_to be_valid
    end

    it 'refuse negatives in the database' do
      goods = create(:catalog_goods)

      expect { goods.update_column(:pack_quantity_in_pack, -1) }.to raise_error(ActiveRecord::StatementInvalid) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  describe 'image paths' do
    it 'must be a list of strings', :aggregate_failures do
      expect(build(:catalog_goods, image_paths: [ 'a.jpg', 'b.jpg' ])).to be_valid
      expect(build(:catalog_goods, image_paths: [ 1, 2 ])).not_to be_valid
      expect(build(:catalog_goods, image_paths: { 'a' => 'b' })).not_to be_valid
      expect(build(:catalog_goods, image_paths: nil)).not_to be_valid
    end
  end

  it 'refuses to delete a dictionary entry that a product uses' do
    form = create(:catalog_goods_form)
    create(:catalog_goods, form:)

    expect { form.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  it 'refuses to delete a restriction that a product uses' do
    restriction = create(:catalog_goods_restriction)
    create(:catalog_goods, driver_restriction: restriction)

    expect { restriction.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  it 'refuses to delete a group that has products' do
    goods = create(:catalog_goods)

    expect { goods.goods_group.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  it 'refuses to delete a product that has a provider link' do
    link = create(:provider_link, linkable: create(:catalog_goods))

    expect { link.linkable.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

# == Schema Information
#
# Table name: catalog_goods
#
#  id                                    :bigint           not null, primary key
#  composition                           :text
#  dosage                                :string
#  hidden                                :boolean          default(FALSE), not null
#  image_paths                           :jsonb            not null
#  in_medication_program                 :boolean          default(FALSE), not null
#  instruction_html                      :text
#  is_recipe                             :boolean          default(FALSE), not null
#  is_strict_recipe                      :boolean          default(FALSE), not null
#  mnn                                   :string
#  morion_code                           :string
#  name                                  :string
#  pack_quantity_in_pack                 :integer
#  pack_quantity_in_unit                 :integer
#  pack_quantity_unit_in_pack            :integer
#  pack_unit_name                        :string
#  release_form                          :string
#  withdrawn                             :boolean          default(FALSE), not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  adult_restriction_id                  :bigint
#  child_restriction_id                  :bigint
#  core_inn_id                           :integer
#  diabetic_restriction_id               :bigint
#  driver_restriction_id                 :bigint
#  form_id                               :bigint
#  goods_group_id                        :bigint           not null
#  measure_id                            :bigint
#  pregnant_and_lactating_restriction_id :bigint
#  price_group_id                        :bigint
#  temperature_mode_id                   :bigint
#
# Indexes
#
#  index_catalog_goods_on_goods_group_id  (goods_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (adult_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (child_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (diabetic_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (driver_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (form_id => catalog_goods_forms.id)
#  fk_rails_...  (goods_group_id => catalog_goods_groups.id)
#  fk_rails_...  (measure_id => catalog_goods_measures.id)
#  fk_rails_...  (pregnant_and_lactating_restriction_id => catalog_goods_restrictions.id)
#  fk_rails_...  (price_group_id => catalog_goods_price_groups.id)
#  fk_rails_...  (temperature_mode_id => catalog_goods_temperature_modes.id)
#
# Check Constraints
#
#  catalog_goods_image_paths_check   (jsonb_typeof(image_paths) = 'array'::text)
#  catalog_goods_in_pack_check       (pack_quantity_in_pack IS NULL OR pack_quantity_in_pack >= 0)
#  catalog_goods_in_unit_check       (pack_quantity_in_unit IS NULL OR pack_quantity_in_unit >= 0)
#  catalog_goods_unit_in_pack_check  (pack_quantity_unit_in_pack IS NULL OR pack_quantity_unit_in_pack >= 0)
#
