# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin SEO filters' do
  let(:admin) { create(:admin_user, email: 'olena@h24.ua') }
  let(:syrup) { create(:catalog_goods_form, name_uk: 'Сироп') }
  let(:vitamins) { create(:catalog_category, name_uk: 'Вітаміни', slug: 'vitaminy') }

  before do
    Seo::Templates::Defaults.call
    sign_in admin
  end

  def save(path, method: :post, preview: nil, **fields)
    public_send(method, path, params: { seo_filter: fields, preview: }.compact)
  end

  def stocked_filter(**attributes)
    create(:catalog_goods, form: syrup)
    create(:seo_filter, published: true, params: { 'form_id' => [ syrup.id ] }, **attributes)
  end

  describe 'the list' do
    def marked_row(filter) = %(id="seo_filter_#{filter.id}" class="seo-filter-empty")

    it 'marks the row of a published filter that selects no goods and says so', :aggregate_failures do
      empty = create(:seo_filter, :published)

      get admin_seo_filters_path

      expect(response.body).to include(marked_row(empty), 'опубліковано · без товарів')
    end

    it 'leaves the row of a published filter with goods as it is' do
      stocked = stocked_filter

      get admin_seo_filters_path

      expect(response.body).not_to include(marked_row(stocked))
    end

    it 'leaves the row of a draft without goods as it is' do
      draft = create(:seo_filter)

      get admin_seo_filters_path

      expect(response.body).to include(%(id="seo_filter_#{draft.id}"), 'чернетка')
    end

    it 'lists only the removed filters in their scope', :aggregate_failures do
      create(:seo_filter, name_uk: 'Чернетка')
      create(:seo_filter, :published, name_uk: 'Прибрана').remove!

      get admin_seo_filters_path(scope: 'removed')

      expect(response.body).to include('Прибрана')
      expect(response.body).not_to include('Чернетка')
    end
  end

  describe 'creating and changing' do
    def create_filter
      save(admin_seo_filters_path, name_uk: 'Вітаміни для дітей', category_id: vitamins.id,
                                   params: { form_id: [ '', syrup.id.to_s ], producer_id: [ '' ] })
    end

    it 'creates a draft with the address from its name and the parameters chosen' do
      create_filter

      expect(Seo::Filter.last).to have_attributes(slug: 'vitaminy-dlia-ditei', published: false, category: vitamins,
                                                  params: { 'form_id' => [ syrup.id ] })
    end

    it 'shows the address on the front and the parameters on the card of the new filter' do
      create_filter
      follow_redirect!

      expect(response.body).to include('/dobirka/vitaminy-dlia-ditei', 'Форма випуску: Сироп')
    end

    it 'takes an address the editor gives' do
      save(admin_seo_filters_path, name_uk: 'Вітаміни для дітей', slug: 'dytiachi-vitaminy')

      expect(Seo::Filter.last.slug).to eq('dytiachi-vitaminy')
    end

    it 'refuses an id that is not in a dictionary and names the parameter', :aggregate_failures do
      save(admin_seo_filters_path, name_uk: 'Від Bayer', params: { producer_id: [ '999999' ] })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('producer_id')
      expect(Seo::Filter.count).to eq(0)
    end

    it 'saves a prescription scope without asking for anything', :aggregate_failures do
      filter = create(:seo_filter)

      save(admin_seo_filter_path(filter), method: :put, recipe_scope: 'any')

      expect(filter.reload.recipe_scope).to eq('any')
      expect(filter.page_versions.last.object_changes).to include('recipe_scope' => %w[otc any])
    end

    it 'keeps a removed filter from changing until it is restored', :aggregate_failures do
      filter = create(:seo_filter, :published, name_uk: 'Стара').tap(&:remove!)

      save(admin_seo_filter_path(filter), method: :put, name_uk: 'Нова')

      expect(response).to redirect_to(admin_seo_filter_path(filter))
      expect(flash[:alert]).to include('спершу відновіть')
      expect(filter.reload.name_uk).to eq('Стара')
    end
  end

  describe 'the preview of the goods' do
    it 'shows the goods of a new filter without creating it', :aggregate_failures do
      create(:catalog_goods, form: syrup, name_uk: 'Амброксол')

      save(admin_seo_filters_path, name_uk: 'Сиропи', params: { form_id: [ syrup.id.to_s ] }, preview: '1')

      expect(response.body).to include('Товарів, що зараз підпадають під добірку: 1.', 'Амброксол')
      expect(Seo::Filter.count).to eq(0)
    end

    it 'shows the changed goods of a saved filter without saving them', :aggregate_failures do
      filter = create(:seo_filter, params: { 'form_id' => [ create(:catalog_goods_form).id ] })
      create(:catalog_goods, form: syrup)

      save(admin_seo_filter_path(filter), method: :put, params: { form_id: [ syrup.id.to_s ] }, preview: '1')

      expect(response.body).to include('Товарів, що зараз підпадають під добірку: 1.')
      expect(filter.reload.params['form_id']).not_to eq([ syrup.id ])
    end

    it 'says that a filter without goods would be closed to search engines' do
      save(admin_seo_filters_path, name_uk: 'Сиропи', params: { form_id: [ syrup.id.to_s ] }, preview: '1')

      expect(response.body).to include('Товарів, що зараз підпадають під добірку: 0.', 'закрита від індексації')
    end

    it 'shows the wrong parameter instead of a preview', :aggregate_failures do
      save(admin_seo_filters_path, name_uk: 'Від Bayer', params: { producer_id: [ '999999' ] }, preview: '1')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include('Товарів, що зараз підпадають')
    end
  end

  describe 'publishing' do
    it 'refuses a filter without parameters', :aggregate_failures do
      filter = create(:seo_filter)

      put publish_admin_seo_filter_path(filter)

      expect(filter.reload).not_to be_published
      expect(flash[:alert]).to be_present
    end

    it 'publishes a filter without goods and warns that its page is closed to search engines', :aggregate_failures do
      filter = create(:seo_filter, params: { 'form_id' => [ syrup.id ] })

      put publish_admin_seo_filter_path(filter)

      expect(filter.reload).to be_published
      expect(flash[:warning]).to include('закрита від індексації')
    end

    it 'takes a filter off the section', :aggregate_failures do
      filter = stocked_filter(slug: 'syropy')

      put unpublish_admin_seo_filter_path(filter)

      expect(filter.reload).not_to be_published
      expect(Seo::Pages::Resolve.call('/dobirka/syropy').status).to eq(404)
    end

    it 'records who published a filter on its card' do
      filter = create(:seo_filter, params: { 'form_id' => [ syrup.id ] })

      put publish_admin_seo_filter_path(filter)
      get admin_seo_filter_path(filter)

      expect(response.body).to include('olena@h24.ua', 'Опубліковано: ні → так')
    end
  end

  describe 'removing and restoring' do
    let!(:filter) { stocked_filter(name_uk: 'Вітаміни для дітей', slug: 'vitaminy-dlia-ditei') }

    def remove(**fields) = put(remove_admin_seo_filter_path(filter), params: fields)

    it 'leaves the address answering 410', :aggregate_failures do
      remove(outcome: 'gone')

      expect(response).to redirect_to(admin_seo_filter_path(filter))
      expect(Seo::Pages::Resolve.call('/dobirka/vitaminy-dlia-ditei').status).to eq(410)
    end

    it 'leads the address to the page the editor chose', :aggregate_failures do
      vitamins

      remove(outcome: 'redirect', target: '/katalog/vitaminy')

      expect(Seo::Pages::Resolve.call('/dobirka/vitaminy-dlia-ditei').location).to eq('/katalog/vitaminy')
      get admin_seo_redirects_path
      expect(response.body).to include('/dobirka/vitaminy-dlia-ditei')
    end

    it 'keeps the filter when the target is refused', :aggregate_failures do
      hidden = create(:catalog_goods, hidden: true)

      remove(outcome: 'redirect', target: "/tovar/#{hidden.slug}")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Сторінка цілі недоступна.')
      expect(filter.reload).not_to be_removed
    end

    it 'asks for the address of a redirect left empty', :aggregate_failures do
      remove(outcome: 'redirect', target: '')

      expect(response.body).to include('Вкажіть нову адресу.')
      expect(filter.reload).not_to be_removed
    end

    it 'brings a removed filter back as a draft without the redirect from its address', :aggregate_failures do
      vitamins
      remove(outcome: 'redirect', target: '/katalog/vitaminy')

      put restore_admin_seo_filter_path(filter)

      expect(filter.reload).to have_attributes(removed_at: nil, published: false)
      expect(Seo::Pages::Resolve.call('/dobirka/vitaminy-dlia-ditei').status).to eq(404)
    end

    it 'has nothing to restore for a filter that is there' do
      put restore_admin_seo_filter_path(filter)

      expect(flash[:alert]).to include('відновлювати нічого')
    end
  end

  it 'tries the template of a filter page on a filter' do
    filter = create(:seo_filter, name_uk: 'Вітаміни для дітей', category: vitamins)
    texts = { title_uk: '{name}: {category}', description_uk: 'Опис', h1_uk: 'H1', preview: { record_id: filter.id } }

    put admin_seo_template_path(Seo::Template.find_by(page_type: 'filter')), params: { preview: 1, seo_template: texts }

    expect(response.body).to include('Вітаміни для дітей: Вітаміни')
  end

  it 'offers no removed filter to try a template on', :aggregate_failures do
    kept = create(:seo_filter, name_uk: 'Лишилась')
    create(:seo_filter, :published, name_uk: 'Прибрана').remove!

    get preview_options_admin_seo_filters_path

    expect(response.parsed_body['results'].pluck('id')).to eq([ kept.id ])
  end
end
