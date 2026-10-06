# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TreeParentValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Node'

      attr_accessor :parent

      validates :parent, tree_parent: true
    end
  end

  def node(parent = nil) = model.new(parent:)

  it 'accepts a root and a node under another branch', :aggregate_failures do
    expect(node).to be_valid
    expect(node(node(node))).to be_valid
  end

  it 'refuses a node as its own parent' do
    record = node
    record.parent = record

    expect(record).not_to be_valid
  end

  it 'refuses a descendant as the parent' do
    root = node
    child = node(node(root))
    root.parent = child

    expect(root).not_to be_valid
  end

  it 'stops at a cycle above the node instead of looping' do
    first = node
    second = node(first)
    first.parent = second

    expect(node(second)).to be_valid
  end
end
