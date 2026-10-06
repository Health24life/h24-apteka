# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotHiddenValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Cart'

      attr_accessor :drugstore, :goods

      validates :drugstore, not_hidden: true
      validates :goods, not_hidden: { via: :group }
    end
  end

  let(:visible) { double(hidden?: false, group: double(hidden?: false)) }
  let(:hidden) { double(hidden?: true, group: double(hidden?: false)) }
  let(:hidden_group) { double(hidden?: false, group: double(hidden?: true)) }

  it 'accepts a record that is not hidden', :aggregate_failures do
    expect(model.new(drugstore: visible, goods: visible)).to be_valid
  end

  it 'refuses a hidden record', :aggregate_failures do
    cart = model.new(drugstore: hidden, goods: visible)

    expect(cart).not_to be_valid
    expect(cart.errors).to be_added(:drugstore, :hidden)
  end

  it 'counts the hiding of the record named by via too', :aggregate_failures do
    cart = model.new(drugstore: visible, goods: hidden_group)

    expect(cart).not_to be_valid
    expect(cart.errors).to be_added(:goods, :hidden)
  end

  it 'does not look at the parent unless via is given' do
    expect(model.new(drugstore: hidden_group, goods: visible)).to be_valid
  end

  it 'leaves a missing record to the presence checks' do
    expect(model.new(drugstore: nil, goods: nil)).to be_valid
  end
end
