# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeoAdminHelper do
  let(:filter) { create(:seo_filter, slug: 'vitaminy-dlia-ditei') }

  it 'links a filter to its card in the admin' do
    expect(helper.seo_admin_path(filter)).to eq("/admin/seo_filters/#{filter.id}")
  end

  it 'shows the old address of a redirect from a filter page as a filter address' do
    redirect = build(:seo_redirect, page_type: 'filter', slug: 'stara-dobirka', redirectable: filter)

    expect(helper.seo_redirect_source(redirect)).to eq('/dobirka/stara-dobirka')
  end
end
