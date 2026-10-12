# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogLocalesValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Named'

      attr_accessor :name, :changes

      validates :name, catalog_locales: true
    end
  end

  def record(*keys) = model.new(changes: keys.index_with { [ nil, 'Назва' ] })

  it 'accepts a change in a catalog locale' do
    expect(record('name_uk')).to be_valid
  end

  it 'refuses a change in another locale and names it', :aggregate_failures do
    invalid = record('name_uk', 'name_en')

    expect(invalid).not_to be_valid
    expect(invalid.errors.details[:name]).to contain_exactly(error: :not_a_catalog_locale, language: 'en')
  end

  it 'ignores changes of other attributes' do
    expect(record('name', 'slug', 'title_en')).to be_valid
  end
end
