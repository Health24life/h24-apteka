# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin SEO templates' do
  let(:admin) { create(:admin_user) }
  let(:painkillers) { create(:catalog_category, name_uk: 'Знеболювальні', slug: 'zneboliuvalni') }
  let(:general) { Seo::Template.find_by(page_type: 'goods', category_id: nil, is_recipe: nil) }

  before do
    Seo::Templates::Defaults.call
    sign_in admin
  end

  def template_params(**fields)
    { seo_template: { page_type: 'goods', title_uk: '{name} — інструкція', description_uk: '{name}: склад',
                      h1_uk: '{name}', **fields } }
  end

  def preview_params(title, record)
    template_params(title_uk: title).merge(preview: 'Переглянути')
                                    .deep_merge(seo_template: { preview: { record_id: record.id } })
  end

  def stocked(**goods)
    create(:catalog_goods, **goods).tap do |sku|
      create(:catalog_goods_group_category, goods_group: sku.goods_group, category: painkillers, is_primary: true)
    end
  end

  it 'lets any admin see the templates and change one', :aggregate_failures do
    get admin_seo_templates_path
    expect(response.body).to include('{name} {dosage} — інструкція із застосування')

    patch admin_seo_template_path(general), params: { seo_template: { title_uk: '{name} — інструкція' } }
    expect(general.reload.title_uk).to eq('{name} — інструкція')
  end

  it 'creates a template narrowed to a branch and to prescription goods' do
    post admin_seo_templates_path, params: template_params(category_id: painkillers.id, is_recipe: 'true')

    expect(Seo::Template.find_by(category: painkillers, is_recipe: true)).to be_present
  end

  it 'refuses an unknown placeholder and names it', :aggregate_failures do
    post admin_seo_templates_path, params: template_params(page_type: 'category', title_uk: '{name} від {producer}')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('{producer}')
  end

  it 'refuses wording that calls to buy and a second template of the same kind', :aggregate_failures do
    post admin_seo_templates_path, params: template_params(category_id: painkillers.id, title_uk: 'Купити {name}')
    expect(response).to have_http_status(:unprocessable_content)

    post admin_seo_templates_path, params: template_params
    expect(response.body).to include('уже зайнято')
  end

  describe 'the preview' do
    it 'offers a preview button named for what it does' do
      get edit_admin_seo_template_path(general)

      expect(response.body).to include('name="preview" value="Переглянути"')
    end

    it 'shows the texts on the chosen SKU without saving the template', :aggregate_failures do
      goods = stocked(name_uk: 'Нурофен', dosage: '200 мг')

      expect { post admin_seo_templates_path, params: preview_params('{name} {dosage} — інструкція', goods) }
        .not_to change(Seo::Template, :count)
      expect(response.body).to include('Нурофен 200 мг — інструкція')
    end

    it 'asks for a record instead of showing the placeholders empty', :aggregate_failures do
      post admin_seo_templates_path, params: template_params.merge(preview: 'Переглянути')

      expect(response.body).to include('Оберіть запис для перегляду')
      expect(response.body).not_to include('символів, ліміт')
    end

    it 'shows a title that search engines would see cut' do
      post admin_seo_templates_path, params: preview_params("{name} #{'дуже ' * 20}довгий", stocked)

      expect(response.body).to include('буде обрізано')
    end

    it 'offers only the SKUs within the branch of the template', :aggregate_failures do
      inside = stocked(name_uk: 'Нурофен')
      create(:catalog_goods, name_uk: 'Нурофенчик')

      get preview_options_admin_skus_path, params: { category_id: painkillers.id, term: 'Нурофен' }

      expect(response.parsed_body['results'].pluck('id')).to eq([ inside.id ])
    end

    it 'warns after saving when the chosen record would see a text cut' do
      patch admin_seo_template_path(general),
            params: { seo_template: { title_uk: "{name} #{'дуже ' * 20}довгий", preview: { record_id: stocked.id } } }

      expect(flash[:warning]).to include('Title')
    end
  end

  describe 'the preview of a page without records' do
    let(:cart) { Seo::Template.find_by(page_type: 'cart') }
    let(:long_title) { "Кошик #{'дуже ' * 20}довгий" }

    it 'shows the texts as they are, with their length, without a record to choose', :aggregate_failures do
      patch admin_seo_template_path(cart), params: { preview: 'Переглянути', seo_template: { title_uk: long_title } }

      expect(response.body).to include('буде обрізано', "#{long_title.length} символів, ліміт 70")
      expect(response.body).not_to include('Запис для перегляду')
      expect(cart.reload.title_uk).not_to eq(long_title)
    end

    it 'warns after saving a text that would be cut' do
      patch admin_seo_template_path(cart), params: { seo_template: { title_uk: long_title } }

      expect(flash[:warning]).to eq('Title довші за ліміт і будуть обрізані.')
    end
  end

  describe 'removal' do
    it 'keeps the general template of a page type, asked directly too', :aggregate_failures do
      delete admin_seo_template_path(general)

      expect(Seo::Template.exists?(general.id)).to be(true)
      expect(flash[:alert]).to eq('Загальний шаблон типу сторінки не можна видалити.')
    end

    it 'removes a narrower template, and its SKUs take the next one', :aggregate_failures do
      goods = stocked(name_uk: 'Нурофен', slug: 'nurofen')
      narrow = create(:seo_template, category: painkillers, title: 'Знеболювальне {name}')

      delete admin_seo_template_path(narrow)

      expect(Seo::Template.exists?(narrow.id)).to be(false)
      expect(Seo::Pages::Describe.call("/tovar/#{goods.slug}").title).to start_with('Нурофен')
    end
  end

  it 'shows the history of a template on its card' do
    patch admin_seo_template_path(general), params: { seo_template: { h1_uk: '{name} інструкція' } }

    get admin_seo_template_path(general)

    expect(response.body).to include(admin.email, '{name} інструкція')
  end
end
