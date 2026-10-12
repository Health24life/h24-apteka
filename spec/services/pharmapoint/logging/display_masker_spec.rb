# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Logging::DisplayMasker do
  let(:order_part) do
    {
      'ext_drugstore_id' => '5aea4747-43ec-11ed-84af-ecf4bbd48b9a', 'drugstore_id' => 34_494,
      'goods' => [ { 'goods_id' => 1_990_718, 'ext_goods_id' => '8b470a26-43ec-11ed-84af-ecf4bbd48b9a', 'quantity' => 1,
                     'price' => '12.5' } ],
      'online_drugstore_order_number' => 'H24-0000000009', 'total' => '265.99'
    }
  end
  let(:pick_up_order) do
    order_part.merge(
      'customer_first_name' => 'Олена', 'customer_last_name' => 'Коваль', 'customer_phone_number' => '380777777777',
      'customer_email' => 'olena@mail.ua', 'comment' => 'Подзвоніть за годину',
      'delivery' => { 'delivery_type_code' => 'PickUp', 'ettn' => nil, 'postcode' => '12345', 'city' => 'Київ',
                      'street' => 'Братиславська', 'house_number' => '11', 'apartment_number' => '145' },
      'payment' => { 'payment_method_code' => 'cash_in_store' }
    )
  end
  let(:masked_pick_up_order) do
    order_part.merge(
      'customer_first_name' => '[masked]', 'customer_last_name' => '[masked]', 'customer_phone_number' => '[masked]',
      'customer_email' => '[masked]', 'comment' => '[masked]',
      'delivery' => { 'delivery_type_code' => 'PickUp', 'ettn' => nil, 'postcode' => '[masked]', 'city' => '[masked]',
                      'street' => '[masked]', 'house_number' => '[masked]', 'apartment_number' => '[masked]' },
      'payment' => { 'payment_method_code' => '[masked]' }
    )
  end
  let(:recipe_order) do
    { 'recipe_number' => '0000-4942-TE9P-EXAA', 'repayment_code' => '1234', 'drugstore_id' => 38_049,
      'goods_id' => 1_826_972, 'customer_middle_name' => 'Петрівна', 'total' => 0,
      'delivery' => { 'delivery_type_code' => 'ukr_post', 'city' => 'м.Запоріжжя' } }
  end
  let(:catalog_page) do
    { 'data' => [ { 'id' => '122c4abff4ae26d0068e7b4cfce236a6', 'barcode' => '4820000000000', 'name' => 'Аспірин',
                    'producer' => { 'name' => 'Bayer', 'country' => 'Німеччина' } } ],
      'drugstore' => { 'city' => 'Київ', 'street' => 'Хрещатик', 'edrpou' => '38001234', 'tax_number' => '3800123456',
                       'ext_id' => '5aea4747-43ec-11ed-84af-ecf4bbd48b9a' },
      'morion' => '380123', 'order_number' => '50-04-16-44', 'created_at' => '2026-04-16 11:46:21' }
  end

  describe '.body' do
    it 'hides the client, the comment, the delivery address and the payment of an order and keeps the order itself' do
      expect(described_class.body(pick_up_order)).to eq(masked_pick_up_order)
    end

    it 'hides the prescription number and the repayment code of a prescription order' do
      expect(described_class.body(recipe_order)).to eq(
        'recipe_number' => '[masked]', 'repayment_code' => '[masked]', 'drugstore_id' => 38_049,
        'goods_id' => 1_826_972, 'customer_middle_name' => '[masked]', 'total' => 0,
        'delivery' => { 'delivery_type_code' => 'ukr_post', 'city' => '[masked]' }
      )
    end

    it 'hides the client and the prescription in the answer to an order, however deep they stand' do
      answer = { 'data' => { 'order_number' => '2E-2H-X4-K5', 'customer_first_name' => 'Олена',
                             'recipe' => { 'number' => '0000-AMP5-H1KM-MEAM', 'reimbursement_total' => 0 } } }
      masked = { 'order_number' => '2E-2H-X4-K5', 'customer_first_name' => '[masked]',
                 'recipe' => { 'number' => '[masked]', 'reimbursement_total' => 0 } }

      expect(described_class.body(answer)).to eq('data' => masked)
    end

    it 'masks a whole nested value under a personal field and leaves an empty one empty' do
      result = described_class.body('payment' => { 'card' => { 'epz' => '4149XXXXXXXX5807' } }, 'customer_email' => nil)

      expect(result).to eq('payment' => { 'card' => '[masked]' }, 'customer_email' => nil)
    end

    it 'hides a phone, an e-mail and a prescription number in a field nobody has listed' do
      result = described_class.body('contact' => 'тел. +38 (050) 123-45-67', 'note' => [ 'пишіть на a.b@x.com.ua' ],
                                    'rx' => 'рецепт 0000-AMP5-H1KM-MEAM')

      expect(result).to eq('contact' => 'тел. [masked]', 'note' => [ 'пишіть на [masked]' ], 'rx' => 'рецепт [masked]')
    end

    it 'shows a page of the catalog in full' do
      expect(described_class.body(catalog_page)).to eq(catalog_page)
    end

    it 'leaves the stored value as it was' do
      original = pick_up_order.deep_dup

      described_class.body(pick_up_order)

      expect(pick_up_order).to eq(original)
    end
  end

  describe '.text' do
    it 'hides the prescription number in a path and keeps the rest of it' do
      expect(described_class.text('/e-health-recipe/0000-4942-TE9P-EXAA')).to eq('/e-health-recipe/[masked]')
    end

    it 'hides phones written in any of the usual ways' do
      phones = [ '380501234567', '+380501234567', '38 050 123 45 67', '+38 (050) 123-45-67' ]

      expect(phones.map { described_class.text(it) }).to all(eq('[masked]'))
    end

    it 'does not take a longer number for a phone' do
      expect(described_class.text('3805012345678')).to eq('3805012345678')
    end
  end

  describe '.query' do
    it 'hides values that look personal and keeps the rest' do
      expect(described_class.query('phone' => '380501234567', 'page' => 2)).to eq('phone' => '[masked]', 'page' => 2)
    end
  end

  describe '.headers' do
    it 'hides values that look personal and keeps the rest' do
      expect(described_class.headers('x-client' => 'olena@mail.ua', 'accept' => 'application/json'))
        .to eq('x-client' => '[masked]', 'accept' => 'application/json')
    end
  end
end
