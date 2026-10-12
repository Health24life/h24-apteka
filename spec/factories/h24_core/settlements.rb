# frozen_string_literal: true

FactoryBot.define do
  factory :h24_core_settlement, class: 'H24Core::Classification::Address::Settlement' do
    title_translations { { 'uk' => 'Київ' } }
  end
end
