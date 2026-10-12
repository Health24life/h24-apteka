# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Redirect do
  subject(:redirect) { build(:seo_redirect) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:redirectable) }
  it { is_expected.to validate_presence_of(:slug) }

  it 'lists as redirectable exactly the records that have a slug' do
    Rails.application.eager_load!
    sluggable = ActiveRecord::Base.descendants.select { it.include?(Catalog::Sluggable) }.map(&:name)

    expect(described_class::REDIRECTABLE_TYPES).to match_array(sluggable)
  end

  it 'refuses a slug in another format' do
    expect(build(:seo_redirect, slug: 'Old Slug')).not_to be_valid
  end

  it 'refuses the same old slug twice for one kind of record' do
    first = create(:seo_redirect)

    expect(build(:seo_redirect, slug: first.slug)).not_to be_valid
  end

  it 'lets records of different kinds keep the same old slug' do
    first = create(:seo_redirect)

    expect(build(:seo_redirect, slug: first.slug, redirectable: create(:catalog_category))).to be_valid
  end

  it 'refuses another kind of record at the database level' do
    record = create(:seo_redirect)

    expect { record.update_column(:redirectable_type, 'Provider') } # rubocop:disable Rails/SkipsModelValidations
      .to raise_error(ActiveRecord::StatementInvalid, /seo_redirects_type_check/)
  end

  describe 'the period of a redirect' do
    let!(:fresh) { create(:seo_redirect, created_at: 3.months.ago + 1.day) }
    let!(:stale) { create(:seo_redirect, created_at: 3.months.ago - 1.day) }

    it 'counts a redirect as active within the period', :aggregate_failures do
      expect(described_class.active).to contain_exactly(fresh)
      expect(described_class.expired).to contain_exactly(stale)
    end
  end
end

# == Schema Information
#
# Table name: seo_redirects
#
#  id                :bigint           not null, primary key
#  redirectable_type :string           not null
#  slug              :string           not null
#  created_at        :datetime         not null
#  redirectable_id   :bigint           not null
#
# Indexes
#
#  index_seo_redirects_on_redirectable_type_and_redirectable_id  (redirectable_type,redirectable_id)
#  index_seo_redirects_on_redirectable_type_and_slug             (redirectable_type,slug) UNIQUE
#
# Check Constraints
#
#  seo_redirects_slug_check  (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#  seo_redirects_type_check  (redirectable_type::text = ANY (ARRAY['Catalog::Goods'::character varying, 'Catalog::Category'::character varying]::text[]))
#
