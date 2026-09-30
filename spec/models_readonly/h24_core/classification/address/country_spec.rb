# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Core::Classification::Address::Country do
  it 'reads the title in the current locale with fallbacks' do
    country = create(:h24_core_country, title_translations: { 'uk' => 'Україна', 'en' => 'Ukraine' })

    expect(I18n.with_locale(:en) { country.title }).to eq('Ukraine')
  end
end
