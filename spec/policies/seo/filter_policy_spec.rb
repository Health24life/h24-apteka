# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::FilterPolicy do
  let(:admin) { build(:admin_user) }
  let(:changes) { %i[update? edit? seo? slug? publish? unpublish? remove?] }

  def allowed(record, actions) = actions.map { described_class.new(admin, record).public_send(it) }

  it 'lets a filter that is not removed change but not come back', :aggregate_failures do
    filter = build(:seo_filter)

    expect(allowed(filter, changes)).to all(be(true))
    expect(described_class.new(admin, filter).restore?).to be(false)
  end

  it 'lets a removed filter only come back', :aggregate_failures do
    filter = build(:seo_filter, removed_at: Time.current)

    expect(allowed(filter, changes)).to all(be(false))
    expect(described_class.new(admin, filter).restore?).to be(true)
  end

  it 'never deletes a filter from the database, so its address keeps answering' do
    expect(described_class.new(admin, build(:seo_filter)).destroy?).to be(false)
  end

  it 'lets a new filter be created' do
    expect(described_class.new(admin, Seo::Filter).create?).to be(true)
  end
end
