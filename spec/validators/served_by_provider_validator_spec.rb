# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ServedByProviderValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Cart'

      attr_accessor :drugstore, :provider

      validates :drugstore, served_by_provider: true
    end
  end

  let(:provider) { create(:provider) }
  let(:drugstore) { create(:catalog_drugstore) }

  it 'accepts a record the provider holds a link to', :aggregate_failures do
    ProviderLinking.link(provider, drugstore)
    cart = model.new(drugstore:, provider:)

    expect(cart).to be_valid
  end

  it 'refuses a record the provider holds no link to', :aggregate_failures do
    cart = model.new(drugstore:, provider:)

    expect(cart).not_to be_valid
    expect(cart.errors).to be_added(:drugstore, :not_served_by_provider)
  end

  it 'refuses a record that only another provider holds a link to' do
    ProviderLinking.link(create(:provider), drugstore)

    expect(model.new(drugstore:, provider:)).not_to be_valid
  end

  it 'leaves a missing record or a missing provider to the presence checks', :aggregate_failures do
    expect(model.new(drugstore: nil, provider:)).to be_valid
    expect(model.new(drugstore:, provider: nil)).to be_valid
  end

  it 'words the refusal in the locale files' do
    cart = model.new(drugstore:, provider:).tap(&:validate)

    expect(cart.errors.full_messages.join).not_to match(/translation missing/i)
  end
end
