# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Categories::Saver do
  it 'derives the depth from the parent, ignoring a given value', :aggregate_failures do
    root = described_class.call(build(:catalog_category, depth: 5))
    child = described_class.call(build(:catalog_category, parent: root, depth: 0))

    expect(root.reload.depth).to eq(0)
    expect(child.reload.depth).to eq(1)
  end

  it 'shifts the branch below a moved category', :aggregate_failures do
    child = create(:catalog_category, parent: create(:catalog_category))
    grandchild = create(:catalog_category, parent: child)

    described_class.call(child.tap { it.parent = create(:catalog_category, parent: create(:catalog_category)) })

    expect(child.reload.depth).to eq(2)
    expect(grandchild.reload.depth).to eq(3)
  end

  it 're-derives a depth written by hand' do
    child = create(:catalog_category, parent: create(:catalog_category))

    child.depth = 9
    described_class.call(child)

    expect(child.reload.depth).to eq(1)
  end

  it 'leaves the branch alone when the category is only renamed' do
    child = create(:catalog_category, parent: create(:catalog_category))
    allow(Catalog::Trees::DescendantsDepthUpdater).to receive(:call)

    child.name_uk = 'Нова назва'
    described_class.call(child)

    expect(Catalog::Trees::DescendantsDepthUpdater).not_to have_received(:call)
  end

  it 'raises on an invalid category' do
    expect { described_class.call(build(:catalog_category, name_uk: nil)) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
