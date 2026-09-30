# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::SlugGenerator do
  let(:taken_scope) do
    Class.new do
      def initialize(*taken) = @taken = taken

      def exists?(slug:) = @taken.include?(slug)
    end
  end

  def slug_for(text, *taken)
    described_class.call(text, scope: taken_scope.new(*taken))
  end

  it 'transliterates Ukrainian into a URL-safe slug', :aggregate_failures do
    expect(slug_for('Знеболювальні')).to eq('zneboliuvalni')
    expect(slug_for('Вітаміни та мінерали')).to eq('vitaminy-ta-mineraly')
    expect(slug_for('Серцево-судинні засоби')).to eq('sertsevo-sudynni-zasoby')
    expect(slug_for('Ліки для дітей (0-3)')).to eq('liky-dlia-ditei-0-3')
  end

  it 'adds a numeric suffix to a taken slug', :aggregate_failures do
    expect(slug_for('Знеболювальні', 'zneboliuvalni')).to eq('zneboliuvalni-2')
    expect(slug_for('Знеболювальні', 'zneboliuvalni', 'zneboliuvalni-2')).to eq('zneboliuvalni-3')
  end

  it 'keeps a long slug within the maximum length' do
    expect(slug_for('а' * 150)).to eq('a' * Catalog::SLUG_MAX_LENGTH)
  end

  it 'keeps the slug within the maximum length together with the suffix', :aggregate_failures do
    slug = slug_for('а' * 150, 'a' * Catalog::SLUG_MAX_LENGTH)

    expect(slug.length).to eq(Catalog::SLUG_MAX_LENGTH)
    expect(slug).to end_with('-2')
  end

  it 'never leaves a trailing hyphen after truncation', :aggregate_failures do
    slug = slug_for("#{'а' * 99} бв")

    expect(slug).not_to end_with('-')
    expect(slug.length).to be <= 100
  end

  it 'falls back to a fixed word when nothing transliterable is left', :aggregate_failures do
    expect(slug_for('!!!')).to eq('item')
    expect(slug_for('')).to eq('item')
    expect(slug_for(nil)).to eq('item')
    expect(slug_for('!!!', 'item')).to eq('item-2')
  end

  it 'produces slugs that match the catalog format' do
    expect(slug_for('Їжак у тумані')).to match(Catalog::SLUG_FORMAT)
  end
end
