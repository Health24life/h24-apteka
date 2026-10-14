# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::StaticPages::Defaults do
  it 'adds the home page named after its breadcrumb', :aggregate_failures do
    expect(described_class.call).to be(true)
    expect(Seo::StaticPage.home).to have_attributes(name_uk: 'Головна', slug: nil)
  end

  it 'adds nothing the second time', :aggregate_failures do
    described_class.call

    expect(described_class.call).to be(false)
    expect(Seo::StaticPage.count).to eq(1)
  end

  it 'leaves the pages written by editors alone' do
    create(:seo_static_page)

    expect { described_class.call }.to change(Seo::StaticPage, :count).by(1)
  end
end
