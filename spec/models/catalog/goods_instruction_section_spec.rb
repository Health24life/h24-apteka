# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::GoodsInstructionSection do
  subject(:section) { build(:catalog_goods_instruction_section) }

  def stored_texts
    ActiveRecord::Base.connection.select_rows(
      'SELECT catalog_goods_instruction_section_id, locale, body_html ' \
      'FROM catalog_goods_instruction_section_translations'
    )
  end

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:goods).class_name('Catalog::Goods') }
  it { is_expected.to validate_presence_of(:source_title) }
  it { is_expected.to validate_inclusion_of(:code).in_array(Catalog::InstructionSections::CODES) }

  it 'shows the heading of its section in the interface language', :aggregate_failures do
    section = build(:catalog_goods_instruction_section, code: 'pokazannia')

    expect(I18n.with_locale(:uk) { section.title }).to eq('Показання')
    expect(I18n.with_locale(:en) { section.title }).to eq('Indications')
  end

  it 'keeps the heading as written in the instruction apart from the shown one' do
    section = create(:catalog_goods_instruction_section, code: 'pokazannia', source_title: 'ПОКАЗАННЯ:')

    expect(section.reload).to have_attributes(source_title: 'ПОКАЗАННЯ:', title: 'Показання')
  end

  describe 'text' do
    it 'requires the Ukrainian text' do
      expect(build(:catalog_goods_instruction_section, body_html_uk: nil)).not_to be_valid
    end

    it 'treats a whitespace-only text as missing' do
      expect(build(:catalog_goods_instruction_section, body_html_uk: '  ')).not_to be_valid
    end

    it 'stores the text as the Ukrainian translation' do
      section = create(:catalog_goods_instruction_section, body_html_uk: '<p>Біль.</p>')

      expect(stored_texts).to eq([ [ section.id, 'uk', '<p>Біль.</p>' ] ])
    end

    it 'shows the Ukrainian text when the interface language has no translation' do
      section = create(:catalog_goods_instruction_section, body_html_uk: '<p>Біль.</p>')

      expect(I18n.with_locale(:en) { section.reload.body_html }).to eq('<p>Біль.</p>')
    end
  end

  describe 'anchor' do
    it 'refuses a malformed anchor' do
      expect(build(:catalog_goods_instruction_section, anchor: 'Pokazannia 2')).not_to be_valid
    end

    it 'refuses a malformed anchor at the database level' do
      section = create(:catalog_goods_instruction_section)

      expect { section.update_column(:anchor, 'Bad_Anchor') } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /catalog_goods_instruction_sections_anchor_check/)
    end

    it 'refuses a repeated anchor within one SKU' do
      existing = create(:catalog_goods_instruction_section, anchor: 'pokazannia')

      expect(build(:catalog_goods_instruction_section, goods: existing.goods, anchor: 'pokazannia')).not_to be_valid
    end

    it 'refuses a repeated anchor within one SKU at the database level' do
      existing = create(:catalog_goods_instruction_section, anchor: 'pokazannia')
      other = create(:catalog_goods_instruction_section, goods: existing.goods)

      expect { other.update_column(:anchor, 'pokazannia') } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same anchor in another SKU' do
      create(:catalog_goods_instruction_section, anchor: 'pokazannia')

      expect(build(:catalog_goods_instruction_section, anchor: 'pokazannia')).to be_valid
    end
  end

  describe 'position' do
    it 'starts from one' do
      expect(build(:catalog_goods_instruction_section, position: 0)).not_to be_valid
    end

    it 'starts from one at the database level' do
      section = create(:catalog_goods_instruction_section)

      expect { section.update_column(:position, 0) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /catalog_goods_instruction_sections_position_check/)
    end

    it 'refuses a repeated position within one SKU' do
      existing = create(:catalog_goods_instruction_section, position: 1)

      expect(build(:catalog_goods_instruction_section, goods: existing.goods, position: 1)).not_to be_valid
    end

    it 'refuses a repeated position within one SKU at the database level' do
      existing = create(:catalog_goods_instruction_section, position: 1)
      other = create(:catalog_goods_instruction_section, goods: existing.goods, position: 2)

      expect { other.update_column(:position, 1) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'on the SKU' do
    it 'lists the sections in document order' do
      goods = create(:catalog_goods)
      second = create(:catalog_goods_instruction_section, goods:, position: 2)
      first = create(:catalog_goods_instruction_section, goods:, position: 1)

      expect(goods.instruction_sections).to eq([ first, second ])
    end

    it 'removes the sections and their texts together with the SKU', :aggregate_failures do
      section = create(:catalog_goods_instruction_section)

      section.goods.destroy!

      expect(described_class.exists?(section.id)).to be(false)
      expect(stored_texts).to eq([])
    end
  end
end

# == Schema Information
#
# Table name: catalog_goods_instruction_sections
#
#  id           :bigint           not null, primary key
#  anchor       :string           not null
#  code         :string           not null
#  position     :integer          not null
#  source_title :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  goods_id     :bigint           not null
#
# Indexes
#
#  index_catalog_instruction_sections_on_goods_and_anchor    (goods_id,anchor) UNIQUE
#  index_catalog_instruction_sections_on_goods_and_position  (goods_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (goods_id => catalog_goods.id)
#
# Check Constraints
#
#  catalog_goods_instruction_sections_anchor_check    (anchor::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)
#  catalog_goods_instruction_sections_position_check  ("position" >= 1)
#
