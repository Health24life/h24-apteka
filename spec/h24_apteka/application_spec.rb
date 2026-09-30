# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Apteka::Application do
  it 'limits catalog translations to Ukrainian' do
    expect(Rails.configuration.x.catalog_locales).to eq(%i[uk])
  end

  it 'keeps the application locales wider than the catalog locales' do
    expect(I18n.available_locales).to include(:uk, :en)
  end

  it 'treats goods as uncountable', :aggregate_failures do
    expect('goods'.pluralize).to eq('goods')
    expect('goods'.singularize).to eq('goods')
  end

  it 'falls back to Ukrainian for English and to English for Ukrainian', :aggregate_failures do
    expect(I18n.fallbacks[:en]).to include(:uk)
    expect(I18n.fallbacks[:uk]).to include(:en)
  end

  it 'has pg_trgm enabled' do
    expect(ActiveRecord::Base.connection.extension_enabled?('pg_trgm')).to be(true)
  end
end
