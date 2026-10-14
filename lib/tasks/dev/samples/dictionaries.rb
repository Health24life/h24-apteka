# frozen_string_literal: true

# The dictionaries the provider sends: forms, measures, price groups, storage, restrictions, ATC classes, producers.
module DevSamples::Dictionaries
  NAMES = {
    Catalog::Goods::Form => %w[Таблетки Капсули Сироп Краплі Мазь Спрей Порошок Розчин Супозиторії Гель],
    Catalog::Goods::Measure => %w[Упаковка Флакон Туба Ампула Саше],
    Catalog::Goods::PriceGroup => [ 'Звичайна ціна', 'Соціальна ціна', 'Реімбурсація' ],
    Catalog::Goods::TemperatureMode => [ 'Кімнатна', 'Від 2 до 8 °C', 'Не вище 25 °C' ],
    Catalog::Goods::Restriction => [ 'Дозволено', 'Заборонено', 'З обережністю' ]
  }.freeze
  ATC = [
    [ 'A', 'Травний тракт і обмін речовин', nil ], [ 'A02', 'Засоби при порушеннях кислотності', 'A' ],
    [ 'A11', 'Вітаміни', 'A' ], [ 'C', 'Серцево-судинна система', nil ], [ 'C09', 'Засоби, що діють на ренін', 'C' ],
    [ 'J', 'Протимікробні засоби', nil ], [ 'J01', 'Антибактеріальні засоби', 'J' ], [ 'N', 'Нервова система', nil ],
    [ 'N02', 'Анальгетики', 'N' ], [ 'N05', 'Психолептики', 'N' ], [ 'R', 'Дихальна система', nil ],
    [ 'R06', 'Антигістамінні засоби', 'R' ]
  ].freeze
  PRODUCERS = {
    'Reckitt' => 'GB', 'Bayer' => 'DE', 'Фармак' => 'UA', 'Дарниця' => 'UA', 'Борщагівський ХФЗ' => 'UA',
    'KRKA' => 'SI', 'Sanofi' => 'FR', 'Teva' => 'IL', 'Gedeon Richter' => 'HU', 'Novartis' => 'CH', 'Pfizer' => 'US',
    'Артеріум' => 'UA', 'Здоров’я' => 'UA', 'Berlin-Chemie' => 'DE'
  }.freeze

  module_function

  def call(provider)
    NAMES.each { |model, names| names.each { name(model, it, provider) } }
    ATC.each { |code, name, parent| atc(code, name, parent) }
    PRODUCERS.each do |name, country|
      producer = Catalog::Producer.find_or_initialize_by(name:)
      producer.update!(country_code: country)
      DevSamples.link(provider, producer, attrs: { 'name' => name })
    end
  end

  def name(model, name, provider)
    record = DevSamples.by_name(model, name) || model.create!(name_uk: name)
    DevSamples.link(provider, record, attrs: { 'name' => name })
  end

  def atc(code, name, parent)
    Catalog::AtcClass.find_or_create_by!(atc_code: code) do |atc|
      atc.name_uk = name
      atc.parent = Catalog::AtcClass.find_by(atc_code: parent) if parent
    end
  end
end
