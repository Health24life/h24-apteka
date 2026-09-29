# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Core::HstoreTranslated do
  let(:model) do
    Class.new do
      include H24Core::HstoreTranslated

      hstore_translated :title, :title_translations

      def initialize(translations) = @translations = translations

      def [](_column) = @translations
    end
  end

  it 'returns the translation for the requested locale' do
    expect(model.new('uk' => 'Україна', 'en' => 'Ukraine').title(:en)).to eq('Ukraine')
  end

  it 'falls back along the I18n fallback chain' do
    expect(model.new('en' => 'Ukraine').title(:uk)).to eq('Ukraine')
  end

  it 'treats blank translations as missing' do
    expect(model.new('uk' => '', 'en' => 'Ukraine').title(:uk)).to eq('Ukraine')
  end

  it 'returns nil when the column is NULL' do
    expect(model.new(nil).title).to be_nil
  end

  it 'returns nil when no locale in the chain has a value' do
    expect(model.new('ru' => 'Украина').title(:uk)).to be_nil
  end
end
