# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin orders' do
  let(:admin) { create(:admin_user) }
  let(:drugstore) { create(:catalog_drugstore, name: 'Аптека на Хрещатику') }
  let(:sent) do
    create(:order, :submitted, drugstore:, customer_first_name: 'Іван', customer_last_name: 'Коваленко',
                               customer_middle_name: 'Петрович', customer_phone_number: '380501234567',
                               customer_email: 'ivan@mail.ua', drugstore_name: 'Аптека №1', status_name: 'created')
  end
  let(:failed) { create(:order, :submission_failed, customer_phone_number: '380671112233') }
  let(:cart) { create(:order, drugstore:) }

  before { sign_in admin }

  def listed(*orders) = orders.map { response.body.include?(admin_order_path(it)) }

  describe 'list' do
    describe 'tabs' do
      before { [ sent, failed, cart ] }

      it 'shows the sent orders by default' do
        get admin_orders_path

        expect(listed(sent, failed, cart)).to eq([ true, true, false ])
      end

      it 'shows the carts in their own tab, with the drugstore from the directory', :aggregate_failures do
        get admin_orders_path(scope: 'cart')

        expect(listed(sent, failed, cart)).to eq([ false, false, true ])
        expect(response.body).to include('Аптека на Хрещатику')
      end

      it 'shows every order in the tab of all' do
        get admin_orders_path(scope: 'all')

        expect(listed(sent, failed, cart)).to eq([ true, true, true ])
      end
    end

    it 'masks the client and the phone', :aggregate_failures do
      sent

      get admin_orders_path

      expect(response.body).to include('Іван К.', '380*****4567', 'Аптека №1', 'Самовивіз')
      expect(response.body).not_to include('Коваленко', 'Петрович', '380501234567', 'ivan@mail.ua')
    end

    it 'shows the first name alone when there is no last name' do
      sent.update!(customer_last_name: nil)

      get admin_orders_path

      expect(response.body).to include('Іван</td>')
    end

    it 'shows an unknown partner status as the partner wrote it' do
      sent.update!(status_name: 'awaiting_courier')

      get admin_orders_path

      expect(response.body).to include('awaiting_courier')
    end
  end

  describe 'card of a sent order' do
    before do
      address = build(:order_delivery_address, city: 'Київ', street: 'Хрещатик', building: '1', postal_code: nil)
      sent.delivery.update!(delivery_type_code: 'ukr_post', address:)
      sent.items.first.update!(name: 'Парацетамол', producer: 'Дарниця', price: 25.5, total: 51, quantity: 2)
      get admin_order_path(sent)
    end

    it 'shows the numbers and the states' do
      expect(response.body).to include(sent.own_number, sent.provider_order_number, 'Передано партнеру', 'Створено')
    end

    it 'shows the client in full' do
      expect(response.body).to include('Коваленко', 'Іван', 'Петрович', '380501234567', 'ivan@mail.ua', 'гість')
    end

    it 'shows the drugstore, the delivery with its address and the payment' do
      expect(response.body).to include('Аптека №1', admin_drugstore_path(drugstore), 'Укрпошта', 'Київ, Хрещатик, 1',
                                       'Оплата в аптеці')
    end

    it 'shows the items with prices and a link to the SKU' do
      expect(response.body).to include('Парацетамол', 'Дарниця', '25.5', admin_sku_path(sent.items.first.goods))
    end

    it 'never shows the guest keys' do
      expect(response.body).not_to include(sent.token, sent.share_token)
    end
  end

  describe 'other cards' do
    it 'shows an order the partner did not take without its number and status', :aggregate_failures do
      get admin_order_path(failed)

      expect(response.body).to include(failed.own_number, 'Помилка передачі', '380671112233')
      expect(response.body).not_to include('Створено</td>')
    end

    it 'shows an item the catalog does not have from its snapshot' do
      sent.items.first.update!(goods: nil, name: 'Товар партнера')

      get admin_order_path(sent)

      expect(response.body).to include('Товар партнера')
    end

    it 'shows an unknown partner status with its comment' do
      sent.update!(status_name: 'awaiting_courier', status_comment: 'Courier is on the way')

      get admin_order_path(sent)

      expect(response.body).to include('awaiting_courier', 'Courier is on the way')
    end

    it 'shows a guest cart without prices and without the guest keys', :aggregate_failures do
      get admin_order_path(cart)

      expect(response.body).to include('Кошик', admin_drugstore_path(drugstore), 'гість',
                                       admin_sku_path(cart.items.first.goods))
      expect(response.body).not_to include(cart.token, cart.share_token, 'Ціна')
    end
  end

  describe 'search' do
    before { [ sent, failed ] }

    [ '+38 (050) 123-45-67', '0501234567' ].each do |phone|
      it "finds an order by the whole phone written as #{phone}" do
        get admin_orders_path, params: { q: { customer_phone_eq: phone } }

        expect(listed(sent, failed)).to eq([ true, false ])
      end
    end

    it 'finds nothing by a part of a phone' do
      get admin_orders_path, params: { q: { customer_phone_eq: '4567' } }

      expect(listed(sent, failed)).to eq([ false, false ])
    end

    it 'finds an order by the partner number' do
      get admin_orders_path, params: { q: { provider_order_number_eq: sent.provider_order_number } }

      expect(listed(sent, failed)).to eq([ true, false ])
    end

    %w[customer_first_name_cont token_start share_token_eq provider_payload_cont].each do |filter|
      it "ignores the filter #{filter}" do
        get admin_orders_path, params: { q: { filter => 'nothing' } }

        expect(listed(sent, failed)).to eq([ true, true ])
      end
    end
  end

  describe 'sorting' do
    %w[token_asc share_token_desc].each do |order|
      it "ignores #{order}" do
        # Keys that put the older order first either way, against the default newest first.
        older = create(:order, :submitted, token: 'a' * 24, share_token: 'z' * 24)
        newer = create(:order, :submitted, token: 'b' * 24, share_token: 'y' * 24)

        get admin_orders_path, params: { order: }

        expect(response.body.index(admin_order_path(newer))).to be < response.body.index(admin_order_path(older))
      end
    end
  end

  describe 'changes' do
    it 'has no form for a new order or for editing one', :aggregate_failures do
      get '/admin/orders/new'
      expect(response).to have_http_status(:not_found)
      get "/admin/orders/#{sent.id}/edit"
      expect(response).to have_http_status(:not_found)
    end

    it 'refuses to change an order', :aggregate_failures do
      put admin_order_path(sent), params: { order: { customer_first_name: 'Інше' } }

      expect(response).to have_http_status(:not_found)
      expect(sent.reload.customer_first_name).to eq('Іван')
    end

    it 'refuses to delete an order', :aggregate_failures do
      delete admin_order_path(sent)

      expect(response).to have_http_status(:not_found)
      expect(Order.exists?(sent.id)).to be(true)
    end
  end

  describe 'downloads' do
    %w[csv json xml].each do |format|
      it "gives no #{format} of the list or a card", :aggregate_failures do
        get admin_orders_path(format:)
        expect(response).to redirect_to(admin_root_path)
        get admin_order_path(sent, format:)
        expect(response).to redirect_to(admin_root_path)
      end
    end
  end

  describe 'drugstore filter' do
    it 'finds drugstores by name for the filter' do
      drugstore

      get all_options_admin_drugstores_path, params: { term: 'Хрещ' }

      expect(response.parsed_body['results']).to contain_exactly(include('text' => 'Аптека на Хрещатику'))
    end
  end
end
