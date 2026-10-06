# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Trees::DescendantsDepthUpdater do
  let(:moved) { create(:catalog_category, parent: create(:catalog_category)) }

  def reparent(category)
    parent = create(:catalog_category, parent: create(:catalog_category))
    category.update!(parent:, depth: parent.depth + 1)
  end

  def move(category)
    reparent(category)
    described_class.call(category)
  end

  it 'shifts the depth of the whole branch below a moved category', :aggregate_failures do
    grandchild = create(:catalog_category, parent: create(:catalog_category, parent: moved))

    move(moved)

    expect(grandchild.parent.reload.depth).to eq(3)
    expect(grandchild.reload.depth).to eq(4)
  end

  it 'reports how many categories it updated' do
    create(:catalog_category, parent: create(:catalog_category, parent: moved))

    expect(move(moved)).to eq(2)
  end

  it 'leaves categories outside the branch alone' do
    sibling = create(:catalog_category, parent: moved.parent)

    expect { move(moved) }.not_to(change { sibling.reload.depth })
  end

  it 'updates descendants without validating them' do
    child = create(:catalog_category, parent: moved)
    reparent(moved)
    allow_any_instance_of(Catalog::Category).to receive(:valid?).and_return(false) # rubocop:disable RSpec/AnyInstance

    described_class.call(moved)

    expect(child.reload.depth).to eq(3)
  end

  it 'stops at a cycle written past the model' do
    root = create(:catalog_category)
    root.update_column(:parent_id, create(:catalog_category, parent: root).id) # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.call(root.reload)).to eq(1)
  end
end
