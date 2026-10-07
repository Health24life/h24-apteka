# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Linker do
  subject(:linker) { described_class.new(provider, now:) }

  let(:provider) { create(:provider) }
  let(:now) { Time.zone.parse('2026-10-07 10:00') }

  def seen_a_day_later = described_class.new(provider, now: now + 1.day)

  describe '#sync' do
    it 'creates the record and the link at the time the record was seen', :aggregate_failures do
      form = linker.sync(Catalog::GoodsForm, 17, name_uk: 'Таблетки')

      expect(form).to be_persisted
      expect(ProviderLink.find_by(linkable: form)).to have_attributes(external_id: '17', synced_at: now)
    end

    it 'updates the record the same id leads to', :aggregate_failures do
      first = linker.sync(Catalog::GoodsForm, '17', name_uk: 'Таблетки')
      later = seen_a_day_later.sync(Catalog::GoodsForm, '17', name_uk: 'Таблетки, нова')

      expect(later).to eq(first)
      expect(first.reload.name_uk).to eq('Таблетки, нова')
    end

    it 'moves the time of the link on' do
      form = linker.sync(Catalog::GoodsForm, '17', name_uk: 'Таблетки')
      seen_a_day_later.sync(Catalog::GoodsForm, '17', name_uk: 'Таблетки')

      expect(ProviderLink.find_by(linkable: form).synced_at).to eq(now + 1.day)
    end

    it 'lets a block save the record instead' do
      saved = false
      linker.sync(Catalog::GoodsForm, '1', name_uk: 'A') { it.save!; saved = true }

      expect(saved).to be(true)
    end

    it 'saves nothing when the record is invalid', :aggregate_failures do
      expect { linker.sync(Catalog::GoodsForm, '1', name_uk: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(ProviderLink.count).to eq(0)
    end
  end

  describe '#fetch' do
    it 'gives no reference for no id' do
      expect(linker.fetch(Catalog::GoodsForm, nil)).to be_nil
    end

    it 'refuses a reference to a record that is not imported' do
      expect { linker.fetch(Catalog::GoodsForm, '5') }.to raise_error(Catalog::Sync::MissingReference, /GoodsForm 5/)
    end

    it 'returns the record that is there' do
      form = linker.sync(Catalog::GoodsForm, '5', name_uk: 'A')

      expect(linker.fetch(Catalog::GoodsForm, '5')).to eq(form)
    end
  end
end
