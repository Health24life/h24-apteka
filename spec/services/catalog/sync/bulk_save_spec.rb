# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::BulkSave do
  subject(:bulk) { described_class.new(linker, tracker) }

  let(:provider) { create(:provider) }
  let(:now) { Time.zone.parse('2026-10-12 10:00') }
  let(:linker) { Catalog::Sync::Linker.new(provider, now:) }
  let(:tracker) { Catalog::Sync::RunTracker.start(provider:, kind: 'goods_groups') }
  let(:group) { create(:catalog_goods_group) }

  def entry(id, **attributes) = described_class::Entry.new(external_id: id, attributes:, payload: nil)

  def goods(id, name) = entry(id, goods_group: group, name_uk: name, withdrawn: false)

  def next_step(at: now + 1.day) = described_class.new(Catalog::Sync::Linker.new(provider, now: at), tracker)

  it 'saves new records with their translations and links in one insert per table', :aggregate_failures do
    statements = QueryLog.capture { bulk.call(Catalog::Goods, [ goods('1', 'Аспірин'), goods('2', 'Цитрамон') ]) }

    expect(Catalog::Goods.find_linked(provider, '2').name_uk).to eq('Цитрамон')
    expect(%w[catalog_goods catalog_goods_translations provider_links].map { QueryLog.inserts_into(statements, it) })
      .to eq([ 1, 1, 1 ])
  end

  it 'stores no empty translation for a locale the provider did not give' do
    bulk.call(Catalog::Goods, [ goods('1', 'Аспірин') ])

    expect(Catalog::Goods::Translation.pluck(:locale)).to eq([ 'uk' ])
  end

  it 'updates the records that are there instead of adding others', :aggregate_failures do
    bulk.call(Catalog::Goods, [ goods('1', 'Аспірин') ])

    next_step.call(Catalog::Goods, [ goods('1', 'Аспірин C') ])

    expect(Catalog::Goods.sole.name_uk).to eq('Аспірин C')
    expect(Catalog::Goods::Translation.count).to eq(1)
    expect(Provider::Link.sole.synced_at).to eq(now + 1.day)
  end

  it 'only moves the links on for records that did not change', :aggregate_failures do
    updated_at = bulk.call(Catalog::Goods, [ goods('1', 'Аспірин') ]).fetch('1').updated_at

    statements = QueryLog.capture { next_step.call(Catalog::Goods, [ goods('1', 'Аспірин') ]) }

    expect(statements.grep(/INSERT INTO "catalog_goods|UPDATE "catalog_goods/)).to be_empty
    expect(Catalog::Goods.sole.updated_at).to eq(updated_at)
    expect(Provider::Link.sole.synced_at).to eq(now + 1.day)
  end

  it 'gives two new records with the same name different slugs in the same insert', :aggregate_failures do
    saved = nil
    statements = QueryLog.capture { saved = bulk.call(Catalog::Goods, [ goods('1', 'Аспірин'), goods('2', 'Аспірин') ]) }

    expect(saved.values.map(&:slug)).to contain_exactly('aspiryn', 'aspiryn-2')
    expect(QueryLog.inserts_into(statements, 'catalog_goods')).to eq(1)
  end

  it 'logs a record that fails validation and saves the rest', :aggregate_failures do
    saved = bulk.call(Catalog::Goods, [ goods('1', nil), goods('2', 'Цитрамон') ])

    expect(saved.keys).to eq([ '2' ])
    expect(tracker.run.failures.sole).to have_attributes(entity_type: 'Catalog::Goods', external_id: '1',
                                                         error_class: 'ActiveRecord::RecordInvalid')
  end

  it 'saves the records one by one when the database refuses the batch', :aggregate_failures do
    allow(Catalog::Goods).to receive(:import).and_raise(ActiveRecord::RecordNotUnique, 'duplicate key')

    saved = bulk.call(Catalog::Goods, [ goods('1', 'Аспірин'), goods('2', 'Цитрамон') ])

    expect(saved.keys).to contain_exactly('1', '2')
    expect(Provider::Link.where(linkable_type: 'Catalog::Goods').count).to eq(2)
    expect(tracker.run.failures).to be_empty
  end

  def hide_all_before_import
    allow(Catalog::Goods).to receive(:import).and_wrap_original do |import, *args, **options|
      Catalog::Goods.update_all(hidden: true) # rubocop:disable Rails/SkipsModelValidations
      import.call(*args, **options)
    end
  end

  it 'keeps what others changed in the columns the provider does not give', :aggregate_failures do
    bulk.call(Catalog::Goods, [ goods('1', 'Аспірин') ])
    hide_all_before_import

    next_step.call(Catalog::Goods, [ goods('1', 'Аспірин C') ])

    expect(Catalog::Goods.sole).to have_attributes(name_uk: 'Аспірин C', hidden: true)
  end

  it 'saves the records one by one when a value cannot be written', :aggregate_failures do
    too_big = entry('1', goods_group: group, name_uk: 'Аспірин', pack_quantity_in_pack: 3_000_000_000)

    saved = bulk.call(Catalog::Goods, [ too_big, goods('2', 'Цитрамон') ])

    expect(saved.keys).to eq([ '2' ])
    expect(tracker.run.failures.sole).to have_attributes(external_id: '1', entity_type: 'Catalog::Goods')
  end

  it 'leaves the associations of a saved record to be read from the database' do
    saved = bulk.call(Catalog::Goods, [ goods('1', 'Аспірин') ]).fetch('1')
    Catalog::Goods::InstructionSection.create!(goods_id: saved.id, position: 1, anchor: 'x', source_title: 'X',
                                               code: Catalog::Instructions::Sections::CODES.first,
                                               body_html_uk: '<p>x</p>')

    expect(saved.instruction_sections.to_a.size).to eq(1)
  end
end
