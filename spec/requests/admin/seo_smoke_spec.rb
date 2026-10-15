# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin SEO screens' do
  let(:admin) { create(:admin_user) }
  let(:category) { create(:catalog_category, slug: 'liky') }
  let(:goods) { create(:catalog_goods, slug: 'nurofen') }
  let(:page) { create(:seo_static_page, :published, slug: 'umovy') }
  let(:template) { Seo::Template.first }

  before do
    Seo::Templates::Defaults.call
    Seo::StaticPages::Defaults.call
    create(:seo_override, target: category, title_uk: 'Ліки', seo_text_uk: '<p>Текст</p>')
    goods.update!(slug: 'nurofen-forte')
    sign_in admin
  end

  def template_screens
    [ admin_seo_templates_path, admin_seo_template_path(template), new_admin_seo_template_path,
      edit_admin_seo_template_path(template) ]
  end

  def page_screens
    [ admin_categories_path, admin_category_path(category), seo_admin_category_path(category),
      slug_admin_category_path(category), admin_sku_path(goods), seo_admin_sku_path(goods), slug_admin_sku_path(goods) ]
  end

  def static_page_screens
    [ admin_static_pages_path, admin_static_page_path(page), new_admin_static_page_path,
      edit_admin_static_page_path(page), admin_static_page_path(Seo::StaticPage.home) ]
  end

  def redirect_screens
    [ admin_seo_redirects_path, admin_seo_redirect_path(Seo::Redirect.first), new_admin_seo_redirect_path,
      import_admin_seo_redirects_path, admin_seo_histories_path ]
  end

  def filter_screens
    filter = create(:seo_filter, :published, category:)
    removed = create(:seo_filter, :published).tap(&:remove!)
    [ admin_seo_filters_path, admin_seo_filter_path(filter), new_admin_seo_filter_path,
      edit_admin_seo_filter_path(filter), seo_admin_seo_filter_path(filter), slug_admin_seo_filter_path(filter),
      remove_admin_seo_filter_path(filter), admin_seo_filter_path(removed),
      edit_admin_seo_template_path(Seo::Template.find_by(page_type: 'filter')) ]
  end

  def failing(paths) = paths.reject { get(it) && response.ok? }

  it 'opens every SEO screen' do
    expect(failing(template_screens + page_screens + static_page_screens + redirect_screens + filter_screens)).to eq([])
  end
end
