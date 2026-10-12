# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Linker do
  subject(:linker) { described_class.new(provider, now:) }

  let(:provider) { create(:provider) }
  let(:now) { Time.zone.parse('2026-10-07 10:00') }

  def seen_a_day_later = described_class.new(provider, now: now + 1.day)

  describe '#sync' do
    it 'creates the record and the link at the time the record was seen', :aggregate_failures do
      form = linker.sync(Catalog::Goods::Form, 17, name_uk: 'Таблетки')

      expect(form).to be_persisted
      expect(Provider::Link.find_by(linkable: form)).to have_attributes(external_id: '17', synced_at: now)
    end

    it 'updates the record the same id leads to', :aggregate_failures do
      first = linker.sync(Catalog::Goods::Form, '17', name_uk: 'Таблетки')
      later = seen_a_day_later.sync(Catalog::Goods::Form, '17', name_uk: 'Таблетки, нова')

      expect(later).to eq(first)
      expect(first.reload.name_uk).to eq('Таблетки, нова')
    end

    it 'moves the time of the link on' do
      form = linker.sync(Catalog::Goods::Form, '17', name_uk: 'Таблетки')
      seen_a_day_later.sync(Catalog::Goods::Form, '17', name_uk: 'Таблетки')

      expect(Provider::Link.find_by(linkable: form).synced_at).to eq(now + 1.day)
    end

    it 'lets a block save the record instead' do
      saved = false
      linker.sync(Catalog::Goods::Form, '1', name_uk: 'A') { it.save!; saved = true }

      expect(saved).to be(true)
    end

    it 'saves nothing when the record is invalid', :aggregate_failures do
      expect { linker.sync(Catalog::Goods::Form, '1', name_uk: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Provider::Link.count).to eq(0)
    end
  end

  describe '#fetch' do
    it 'gives no reference for no id' do
      expect(linker.fetch(Catalog::Goods::Form, nil)).to be_nil
    end

    it 'refuses a reference to a record that is not imported' do
      expect do
        linker.fetch(Catalog::Goods::Form, '5')
      end.to raise_error(Catalog::Sync::MissingReference, /Catalog::Goods::Form 5/)
    end

    it 'returns the record that is there' do
      form = linker.sync(Catalog::Goods::Form, '5', name_uk: 'A')

      expect(linker.fetch(Catalog::Goods::Form, '5')).to eq(form)
    end

    it 'asks the database once per reference within a step' do
      linker.sync(Catalog::Goods::Form, '5', name_uk: 'A')
      fresh = described_class.new(provider, now:)

      statements = QueryLog.capture { 3.times { fresh.fetch(Catalog::Goods::Form, '5') } }

      expect(statements.size).to eq(1)
    end
  end

  describe '#preload and #build' do
    it 'finds the records of a batch in one query', :aggregate_failures do
      %w[1 2].each { linker.sync(Catalog::Goods::Form, it, name_uk: "F#{it}") }
      fresh = described_class.new(provider, now:)

      statements = QueryLog.capture { fresh.preload(Catalog::Goods::Form, %w[1 2 3]) }

      expect(statements.size).to eq(1)
      expect(QueryLog.capture { %w[1 2 3].map { fresh.find(Catalog::Goods::Form, it) } }).to be_empty
    end

    it 'builds a new record with its link and saves nothing', :aggregate_failures do
      form = linker.build(Catalog::Goods::Form, '9', name_uk: 'Нова')

      expect(form).to be_new_record
      expect(linker.link_of(form)).to have_attributes(external_id: '9', synced_at: now, provider:)
      expect(Provider::Link.count).to eq(0)
    end

    it 'builds onto the record that is there and moves its link on', :aggregate_failures do
      form = linker.sync(Catalog::Goods::Form, '9', name_uk: 'Стара')
      later = seen_a_day_later.tap { it.preload(Catalog::Goods::Form, [ '9' ]) }

      built = later.build(Catalog::Goods::Form, '9', name_uk: 'Нова')

      expect(built).to have_attributes(id: form.id, name_uk: 'Нова')
      expect(later.link_of(built)).to have_attributes(synced_at: now + 1.day, persisted?: true)
    end

    it 'loads the translations of a model kept in a table, so a new name updates the row that is there' do
      group = create(:catalog_goods_group)
      ProviderLinking.link(provider, group).update!(external_id: '7')
      linker.preload(Catalog::Goods::Group, [ '7' ])

      expect(linker.find(Catalog::Goods::Group, '7').translations).to be_loaded
    end

    it 'forgets what it knows of a model' do
      linker.preload(Catalog::Goods::Form, [ '4' ])
      form = Catalog::Goods::Form.create!(name_uk: 'Пізніше')
      ProviderLinking.link(provider, form).update!(external_id: '4')

      linker.forget(Catalog::Goods::Form)

      expect(linker.find(Catalog::Goods::Form, '4')).to eq(form)
    end
  end
end
