# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnabledValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Cart'

      attr_accessor :provider

      validates :provider, enabled: true
    end
  end

  it 'accepts an enabled record' do
    expect(model.new(provider: build(:provider, active: true))).to be_valid
  end

  it 'refuses a disabled record', :aggregate_failures do
    cart = model.new(provider: build(:provider, active: false))

    expect(cart).not_to be_valid
    expect(cart.errors).to be_added(:provider, :disabled)
  end

  it 'leaves a missing record to the presence checks' do
    expect(model.new(provider: nil)).to be_valid
  end
end
