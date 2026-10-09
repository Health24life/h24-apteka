# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Slugs::Generator do
  let(:taken_scope) do
    Class.new do
      attr_reader :lookups

      def initialize(*taken)
        @taken = taken
        @lookups = 0
      end

      def where(slug:)
        @lookups += 1
        @found = @taken & slug
        self
      end

      def pluck(_column) = @found
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

  it 'turns underscores into hyphens and squeezes repeated hyphens', :aggregate_failures do
    expect(slug_for('Вітамін_С')).to eq('vitamin-s')
    expect(slug_for('А__Б -- В')).to eq('a-b-v')
    expect(slug_for('_Вітамін_')).to eq('vitamin')
  end

  it 'always produces a slug matching the catalog format', :aggregate_failures do
    [ 'Вітамін_С', 'a_b__c', '--x--', 'Ліки (0_3)' ].each do |text|
      expect(slug_for(text)).to match(Catalog::Sluggable::FORMAT)
    end
  end

  it 'adds a numeric suffix to a taken slug', :aggregate_failures do
    expect(slug_for('Знеболювальні', 'zneboliuvalni')).to eq('zneboliuvalni-2')
    expect(slug_for('Знеболювальні', 'zneboliuvalni', 'zneboliuvalni-2')).to eq('zneboliuvalni-3')
  end

  it 'looks up a long run of taken suffixes in one query', :aggregate_failures do
    scope = taken_scope.new('paratsetamol', *(2..30).map { "paratsetamol-#{it}" })

    expect(described_class.call('Парацетамол', scope:)).to eq('paratsetamol-31')
    expect(scope.lookups).to eq(1)
  end

  it 'keeps looking past a whole batch of taken suffixes' do
    taken = [ 'item', *(2..120).map { "item-#{it}" } ]

    expect(slug_for('!!!', *taken)).to eq('item-121')
  end

  it 'drops every form of the apostrophe, as the KMU table does', :aggregate_failures do
    %w[М'ята М’ята Мʼята М‘ята М`ята М´ята].each do |name|
      expect(slug_for(name)).to eq('miata')
    end
  end

  it 'reads the Russian-only letters as their closest Ukrainian ones', :aggregate_failures do
    expect(slug_for('Эналаприл')).to eq('enalapryl')
    expect(slug_for('Ёлка')).to eq('elka')
    expect(slug_for('Сыворотка')).to eq('syvorotka')
    expect(slug_for('Подъём')).to eq('podem')
  end

  it 'keeps a long slug within the maximum length' do
    expect(slug_for('а' * 150)).to eq('a' * Catalog::Sluggable::MAX_LENGTH)
  end

  it 'keeps the slug within the maximum length together with the suffix', :aggregate_failures do
    slug = slug_for('а' * 150, 'a' * Catalog::Sluggable::MAX_LENGTH)

    expect(slug.length).to eq(Catalog::Sluggable::MAX_LENGTH)
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
    expect(slug_for('Їжак у тумані')).to match(Catalog::Sluggable::FORMAT)
  end
end
