# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Pages::Address do
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua') }

  def address(input) = described_class.call(input, config:)

  it 'takes a path of the front as it is', :aggregate_failures do
    expect(address('/tovar/nurofen')).to have_attributes(path: '/tovar/nurofen', ok?: true)
    expect(address('/')).to have_attributes(path: '/')
  end

  it 'takes a full address on the front host and normalises it', :aggregate_failures do
    expect(address(' https://apteka.h24.ua/Tovar/Nurofen-Stare/?utm_source=fb ').path).to eq('/tovar/nurofen-stare')
    expect(address('https://APTEKA.h24.ua').path).to eq('/')
  end

  it 'refuses an address on another host' do
    expect(address('https://h24.ua/doctors').error).to eq(:other_host)
  end

  it 'refuses what is not an address', :aggregate_failures do
    expect(address('tovar/nurofen').error).to eq(:invalid)
    expect(address('mailto:info@h24.ua').error).to eq(:invalid)
    expect(address('https://apteka.h24.ua/ bad').error).to eq(:invalid)
    expect(address('  ').error).to eq(:blank)
  end
end
