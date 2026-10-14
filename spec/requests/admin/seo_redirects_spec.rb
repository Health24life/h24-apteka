# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin SEO redirects' do
  let(:admin) { create(:admin_user, email: 'olena@h24.ua') }
  let!(:category) { create(:catalog_category, name_uk: 'Знеболювальні', slug: 'zneboliuvalni') }
  let(:front) { Seo::Config.current.front_base_url! }

  before { sign_in admin }

  def location_of(path) = Seo::Pages::Describe.call(path).location

  def upload(csv)
    post import_admin_seo_redirects_path, params: { file: Rack::Test::UploadedFile.new(StringIO.new(csv), 'text/csv',
                                                                                       original_filename: 'r.csv') }
  end

  describe 'a redirect set by hand' do
    it 'takes a full address and keeps its normal path', :aggregate_failures do
      create(:catalog_goods, slug: 'nurofen-stare', withdrawn: true)

      post admin_seo_redirects_path,
           params: { source: "#{front}/tovar/Nurofen-Stare/", target: '/katalog/zneboliuvalni' }

      expect(Seo::Redirect.sole).to have_attributes(manual: true, slug: 'nurofen-stare', redirectable: category)
      expect(location_of('/tovar/nurofen-stare')).to eq('/katalog/zneboliuvalni')
    end

    it 'refuses an old address that has a page' do
      post admin_seo_redirects_path, params: { source: "/tovar/#{create(:catalog_goods).slug}", target: '/' }

      expect(response.body).to include('За старою адресою є сторінка')
    end

    it 'refuses an address outside the section' do
      post admin_seo_redirects_path, params: { source: '/tovar/nema', target: 'https://h24.ua/doctors' }

      expect(response.body).to include('Допустимі лише адреси розділу')
    end

    it 'refuses a target off the storefront', :aggregate_failures do
      hidden = create(:catalog_goods, hidden: true)

      post admin_seo_redirects_path, params: { source: '/tovar/nema', target: "/tovar/#{hidden.slug}" }

      expect(response.body).to include('Сторінка цілі недоступна')
      expect(Seo::Redirect.count).to eq(0)
    end

    it 'leads to the page where an address that redirects ends' do
      medicines = create(:catalog_category, slug: 'liky')
      medicines.update!(slug: 'likarski-zasoby')

      post admin_seo_redirects_path, params: { source: '/tovar/nema', target: '/katalog/liky' }

      expect(Seo::Redirect.find_by(manual: true).redirectable).to eq(medicines)
    end

    it 'leads a redirect to another page', :aggregate_failures do
      redirect = create(:seo_redirect, manual: true, page_type: 'goods', slug: 'nema', redirectable: category)
      other = create(:catalog_category, slug: 'inshi')

      put admin_seo_redirect_path(redirect), params: { target: '/katalog/inshi' }

      expect(redirect.reload.redirectable).to eq(other)
      expect(location_of('/tovar/nema')).to eq('/katalog/inshi')
    end

    it 'removes a redirect and keeps who did it in the history', :aggregate_failures do
      redirect = create(:seo_redirect, manual: true, page_type: 'goods', slug: 'nema', redirectable: category)

      delete admin_seo_redirect_path(redirect)
      get admin_seo_histories_path

      expect(Seo::Version.find_by(item: redirect, event: 'destroy').author).to eq(admin)
      expect(response.body).to include('olena@h24.ua', 'видалено')
    end

    it 'marks a redirect that does not act' do
      create(:seo_redirect, manual: true, page_type: 'goods', slug: 'nema',
                            redirectable: create(:catalog_goods, hidden: true))

      get admin_seo_redirects_path

      expect(response.body).to include('не діє')
    end
  end

  describe 'a CSV file' do
    it 'creates every redirect of a file without errors' do
      upload("стара;нова\n/tovar/a;/katalog/zneboliuvalni\n/tovar/b;/katalog/zneboliuvalni\n")

      expect(flash[:notice]).to eq('Створено переадресацій: 2.')
    end

    it 'creates nothing and names the wrong row', :aggregate_failures do
      upload("стара,нова\n/tovar/a,/katalog/zneboliuvalni\n/tovar/b,https://h24.ua/x\n")

      expect(Seo::Redirect.count).to eq(0)
      expect(response.body).to include('<td>2</td>', 'Допустимі лише адреси розділу')
    end

    it 'names both rows of the same old address' do
      upload("стара,нова\n/tovar/a,/katalog/zneboliuvalni\n/tovar/A/,/katalog/zneboliuvalni\n")

      expect(response.body.scan('трапляється у файлі ще раз').size).to eq(2)
    end
  end

  def template_by(author)
    PaperTrail.request(controller_info: { author: }) { create(:seo_template, category: create(:catalog_category)) }
  end

  it 'filters the history by its author', :aggregate_failures do
    other = create(:admin_user, email: 'taras@h24.ua')
    [ other, admin ].each { template_by(it) }

    get admin_seo_histories_path, params: { q: { author_id_eq: other.id } }

    expect(response.body).to include('taras@h24.ua')
    expect(response.body).not_to include('olena@h24.ua</td>')
  end
end
