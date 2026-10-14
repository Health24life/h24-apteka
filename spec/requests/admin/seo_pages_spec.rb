# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin SEO of pages' do
  let(:admin) { create(:admin_user, email: 'olena@h24.ua') }
  let(:category) { create(:catalog_category, name_uk: 'Знеболювальні', slug: 'zneboliuvalni') }
  let(:goods) { create(:catalog_goods, name_uk: 'Нурофен', slug: 'nurofen', dosage: '200 мг') }

  before do
    Seo::Templates::Defaults.call
    sign_in admin
  end

  def seo_of(path) = Seo::Pages::Describe.call(path)

  def set_seo(path, **fields) = put(path, params: { seo_override: { robots: 'auto', **fields } })

  describe 'the SEO set by hand' do
    it 'sends the title of a SKU set by hand to the SEO endpoint', :aggregate_failures do
      set_seo(seo_admin_sku_path(goods), title_uk: 'Нурофен 200 мг: інструкція')

      expect(response).to redirect_to(admin_sku_path(goods))
      expect(seo_of('/tovar/nurofen').title).to eq('Нурофен 200 мг: інструкція')
    end

    it 'gives a category its template back once a field is emptied', :aggregate_failures do
      create(:seo_override, target: category, description_uk: 'Свій опис')

      set_seo(seo_admin_category_path(category), description_uk: '')

      expect(seo_of('/katalog/zneboliuvalni').description).to include('Знеболювальні: лікарські засоби')
    end

    it 'fills the empty fields of the form with the texts of the template' do
      get seo_admin_sku_path(goods)

      expect(response.body).to include('value="Нурофен — інструкція із застосування"')
    end

    it 'keeps a text saved as the template gives it following the template', :aggregate_failures do
      set_seo(seo_admin_sku_path(goods), title_uk: 'Нурофен — інструкція із застосування ', h1_uk: 'Нурофен для дітей')
      Seo::Template.find_by(page_type: 'goods').update!(title: '{name} — склад і застосування')

      expect(goods.reload.seo_override).to have_attributes(title_uk: nil, h1_uk: 'Нурофен для дітей')
      expect(seo_of('/tovar/nurofen').title).to eq('Нурофен — склад і застосування')
    end

    it 'sets the meta tags of the home page' do
      Seo::StaticPages::Defaults.call
      set_seo(seo_admin_static_page_path(Seo::StaticPage.home), title_uk: 'Аптека Health24 — бронювання ліків')

      expect(seo_of('/').title).to eq('Аптека Health24 — бронювання ліків')
    end

    it 'keeps a title that is too long and says so', :aggregate_failures do
      set_seo(seo_admin_sku_path(goods), title_uk: 'Н' * 85)

      expect(goods.reload.seo_override.title_uk.length).to eq(85)
      expect(flash[:warning]).to include('85 символів')
    end

    it 'cleans the SEO text and says so', :aggregate_failures do
      set_seo(seo_admin_category_path(category), seo_text_uk: '<p>Текст</p><iframe src="https://e.com"></iframe>')

      expect(category.reload.seo_override.seo_text_uk).to eq('<p>Текст</p>')
      expect(flash[:warning]).to include('прибрано теги')
    end

    it 'refuses wording that calls to buy' do
      set_seo(seo_admin_sku_path(goods), title_uk: 'Купити Нурофен')

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'shows the current answer of the endpoint and the editor on the card', :aggregate_failures do
      get admin_sku_path(goods)

      expect(response.body).to include('Нурофен — інструкція із застосування',
                                       "href=\"/api/v1/seo/page?path=/tovar/#{goods.slug}\"")
      get seo_admin_sku_path(goods)
      expect(response.body).to include('<trix-editor')
    end
  end

  describe 'the change of a slug' do
    it 'shows the new address and the warning before it saves anything', :aggregate_failures do
      put slug_admin_sku_path(goods), params: { slug: 'nurofen-forte-200' }

      expect(response.body).to include('/tovar/nurofen-forte-200</strong>', 'буде переадресація')
      expect(goods.reload.slug).to eq('nurofen')
    end

    it 'saves the slug and leaves a redirect from the old one', :aggregate_failures do
      put slug_admin_sku_path(goods), params: { slug: 'nurofen-forte', confirmed: '1' }

      expect(response).to redirect_to(admin_sku_path(goods))
      expect(seo_of('/tovar/nurofen').location).to eq('/tovar/nurofen-forte')
      expect(goods.page_versions.find_by(item_type: 'Catalog::Goods').author).to eq(admin)
    end

    it 'refuses a slug another SKU has' do
      create(:catalog_goods, slug: 'ibuprofen')

      put slug_admin_sku_path(goods), params: { slug: 'ibuprofen', confirmed: '1' }

      expect(response.body).to include('уже має інша сторінка')
    end

    it 'refuses a slug a redirect holds for another page' do
      create(:catalog_category, slug: 'liky').update!(slug: 'likarski-zasoby')

      put slug_admin_category_path(category), params: { slug: 'liky', confirmed: '1' }

      expect(response.body).to include('закріплена за іншою сторінкою')
    end

    it 'refuses a slug in another format' do
      put slug_admin_sku_path(goods), params: { slug: 'Нурофен Форте', confirmed: '1' }

      expect(response.body).to include('малі латинські літери')
    end
  end

  describe 'the categories' do
    it 'finds a category by a part of its name' do
      category

      get admin_categories_path, params: { q: { name_cont: 'знебол' } }

      expect(response.body).to include('Знеболювальні', 'zneboliuvalni')
    end

    it 'has no way to change the tree' do
      category

      expect do
        post admin_categories_path, params: { catalog_category: { name_uk: 'Нова' } }
        delete admin_category_path(category)
      end.not_to(change(Catalog::Category, :count))
    end
  end

  describe 'the static pages' do
    def create_page(**fields)
      post admin_static_pages_path, params: { seo_static_page: { name_uk: 'Умови сервісу', content_uk: '<p>Умови</p>',
                                                                 **fields } }
      Seo::StaticPage.find_by(name: { 'uk' => fields[:name_uk] || 'Умови сервісу' })
    end

    it 'creates an unpublished page with a slug from its name', :aggregate_failures do
      page = create_page

      expect(page).to have_attributes(slug: 'umovy-servisu', published: false)
      expect(seo_of('/umovy-servisu').status).to eq(404)
    end

    it 'shows a published page with its text', :aggregate_failures do
      page = create_page

      patch admin_static_page_path(page), params: { seo_static_page: { published: '1' } }

      expect(seo_of('/umovy-servisu')).to have_attributes(status: 200, content: '<p>Умови</p>')
    end

    it 'takes a picture out of the text and says so', :aggregate_failures do
      page = create_page(content_uk: '<p>Умови</p><img src="https://e.com/a.png">')

      expect(page.content_uk).to eq('<p>Умови</p>')
      expect(flash[:warning]).to include('картинки')
    end

    it 'links the card of a page to its address on the front' do
      page = create_page
      url = Seo::Pages::Path.new.url('/umovy-servisu')

      get admin_static_page_path(page)

      expect(response.body).to include(%(<a target="_blank" rel="noopener" href="#{url}">#{url}</a>))
    end

    it 'refuses a slug a route of the section takes' do
      expect { create_page(slug: 'katalog') }.not_to change(Seo::StaticPage, :count)
    end

    it 'removes a page with the redirects to it', :aggregate_failures do
      page = create_page
      page.update!(published: true, slug: 'umovy')

      delete admin_static_page_path(page)

      expect(seo_of('/umovy').status).to eq(404)
      expect(Seo::Redirect.count).to eq(0)
    end

    it 'keeps the home page and its address' do
      Seo::StaticPages::Defaults.call
      home = Seo::StaticPage.home

      delete admin_static_page_path(home)
      put slug_admin_static_page_path(home), params: { slug: 'holovna', confirmed: '1' }

      expect(Seo::StaticPage.home).to eq(home).and(have_attributes(slug: nil))
    end
  end

  it 'refuses a change from someone who is not signed in', :aggregate_failures do
    sign_out admin

    set_seo(seo_admin_sku_path(goods), title_uk: 'Чужий title')

    expect(response).to redirect_to(new_admin_user_session_path)
    expect(goods.reload.seo_override).to be_nil
  end
end
