# frozen_string_literal: true

# Pharmacies of several brands in several cities, some hidden by an operator, withdrawn or incomplete.
module DevSamples::Drugstores
  BRANDS = {
    'АНЦ' => [ 'ТОВ «Аптека низьких цін»', '38001234' ], 'Подорожник' => [ 'ТОВ «Подорожник»', '40123456' ],
    'Бажаємо здоров’я' => [ 'ТОВ «Бажаємо здоров’я»', '35123478' ], 'D.S.' => [ 'ТОВ «Д.С. Аптека»', '41234560' ],
    '9-1-1' => [ 'ТОВ «Аптека 9-1-1»', '39876543' ], nil => [ 'ФОП Коваленко О. І.', '3012345678' ]
  }.freeze
  CITIES = {
    'Київ' => [ 50.4501, 30.5234 ], 'Львів' => [ 49.8419, 24.0316 ], 'Одеса' => [ 46.4686, 30.7406 ],
    'Харків' => [ 49.9935, 36.2304 ], 'Дніпро' => [ 48.4647, 35.0462 ], 'Вінниця' => [ 49.2331, 28.4682 ]
  }.freeze
  STREETS = [ 'вул. Шевченка', 'просп. Свободи', 'вул. Франка', 'вул. Соборна', 'вул. Грушевського' ].freeze
  HOURS = (([ '08:00-21:00' ] * 6) + [ '09:00-18:00' ]).freeze

  module_function

  def call(provider)
    BRANDS.keys.product(CITIES.keys).each_with_index do |(brand, city), index|
      2.times { |number| drugstore(provider, brand, city, (index * 2) + number) }
    end
  end

  def drugstore(provider, brand, city, number)
    external = "ds-#{number + 1}"
    record = Catalog::Drugstore.find_by(ext_drugstore_id: external) || create(brand, city, number, external)
    DevSamples.link(provider, record, external_id: external, attrs: { 'name' => record.name, 'city' => city })
    DevSamples.link(provider, record.brand, attrs: { 'name' => brand }) if record.brand
  end

  def create(brand, city, number, external)
    entity, code = BRANDS.fetch(brand)
    drugstore = Catalog::Drugstore.create!(
      ext_drugstore_id: external, name: "#{brand || 'Аптека'} №#{number + 1}", phone: format('+38044%07d', number),
      brand: brand && Catalog::Drugstore::Brand.find_or_create_by!(name: brand), week_working_hours: HOURS,
      drugstore_legal_entity_name: entity, drugstore_legal_entity_code: code, **flags(number)
    )
    drugstore.create_address!(address(city, number))
    drugstore
  end

  # A street of the city, a little apart from the other pharmacies on the map.
  def address(city, number)
    latitude, longitude = CITIES.fetch(city)
    { address: "#{STREETS[number % STREETS.size]}, #{number + 1}", city:, state: "#{city}ська область",
      latitude: latitude + (number * 0.003), longitude: longitude + (number * 0.003) }
  end

  def flags(number)
    { work_with_reimbursement: number.even?, hidden: number % 17 == 16, withdrawn: number % 19 == 18,
      incomplete: number % 23 == 22 }
  end
end
