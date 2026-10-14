# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Templates::Defaults do
  it 'gives every page type a general template', :aggregate_failures do
    expect(described_class.call).to match_array(Seo::Template.page_types.values)
    expect(Seo::Template.all).to all(be_general)
  end

  it 'leaves a template that is already there and adds only the missing ones', :aggregate_failures do
    own = create(:seo_template, title: 'Свій шаблон {name}')

    expect(described_class.call).not_to include('goods')
    expect(own.reload.title).to eq('Свій шаблон {name}')
  end

  it 'adds nothing the second time' do
    described_class.call

    expect(described_class.call).to eq([])
  end

  it 'takes the wording from the Ukrainian locale', :aggregate_failures do
    described_class.call

    expect(Seo::Template.find_by(page_type: 'goods').title_uk).to eq('{name} {dosage} — інструкція із застосування')
    expect(Seo::Template.find_by(page_type: 'cart').h1_uk).to eq('Кошик')
  end

  it 'has wording for every page type in the locale' do
    missing = Seo::Template.page_types.values.product(Seo::Template::TEXTS).reject do |page_type, text|
      I18n.exists?(:"seo.templates.defaults.#{page_type}.#{text}", :uk)
    end

    expect(missing).to be_empty
  end
end
