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

  it 'writes texts that pass the checks of a template' do
    expect(described_class::TEXTS.keys).to match_array(Seo::Template.page_types.values)
  end
end
