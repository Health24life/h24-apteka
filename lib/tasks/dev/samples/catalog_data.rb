# frozen_string_literal: true

# The tree of categories and the goods groups of the sample catalog.
module DevSamples::CatalogData
  # slug, name, parent
  CATEGORIES = [
    [ 'liky', 'Ліки' ],
    [ 'zneboliuvalni', 'Знеболювальні', 'liky' ],
    [ 'zharoznyzhuvalni', 'Жарознижувальні', 'liky' ],
    [ 'protyzastudni', 'Протизастудні', 'liky' ],
    [ 'antybiotyky', 'Антибіотики', 'liky' ],
    [ 'sertseve', 'Серцево-судинні', 'liky' ],
    [ 'travlennia', 'Травлення', 'liky' ],
    [ 'alerhiia', 'Алергія', 'liky' ],
    [ 'nervova', 'Нервова система', 'liky' ],
    [ 'zaspokiilyvi', 'Заспокійливі', 'nervova' ],
    [ 'snodiini', 'Снодійні', 'nervova' ],
    [ 'vitaminy', 'Вітаміни' ],
    [ 'vitamin-s', 'Вітамін С', 'vitaminy' ],
    [ 'vitamin-d', 'Вітамін D', 'vitaminy' ],
    [ 'multyvitaminy', 'Мультивітаміни', 'vitaminy' ],
    [ 'mineraly', 'Мінерали', 'vitaminy' ],
    [ 'kosmetyka', 'Косметика' ],
    [ 'oblychchia', 'Догляд за обличчям', 'kosmetyka' ],
    [ 'tilo', 'Догляд за тілом', 'kosmetyka' ],
    [ 'medtekhnika', 'Медтехніка' ],
    [ 'tonometry', 'Тонометри', 'medtekhnika' ],
    [ 'termometry', 'Термометри', 'medtekhnika' ],
    [ 'mama-i-dytyna', 'Мама і дитина' ],
    [ 'dytiachi-liky', 'Дитячі ліки', 'mama-i-dytyna' ]
  ].freeze

  # trade name, INN, producer, form, categories (the first is primary), dosages, prescription only
  GROUPS = [
    [ 'Нурофен', 'Ібупрофен', 'Reckitt', 'Таблетки', %w[zneboliuvalni zharoznyzhuvalni], [ '200 мг', '400 мг' ] ],
    [ 'Ібупрофен', 'Ібупрофен', 'Дарниця', 'Таблетки', %w[zneboliuvalni], [ '200 мг', '400 мг' ] ],
    [ 'Парацетамол', 'Парацетамол', 'Фармак', 'Таблетки', %w[zharoznyzhuvalni zneboliuvalni], [ '200 мг', '500 мг' ] ],
    [ 'Аспірин', 'Ацетилсаліцилова кислота', 'Bayer', 'Таблетки', %w[zneboliuvalni], [ '100 мг', '500 мг' ] ],
    [ 'Кеторолак', 'Кеторолак', 'Борщагівський ХФЗ', 'Таблетки', %w[zneboliuvalni], [ '10 мг' ] ],
    [ 'Диклофенак', 'Диклофенак', 'Здоров’я', 'Мазь', %w[zneboliuvalni], [ '1%', '5%' ] ],
    [ 'Терафлю', 'Парацетамол', 'Novartis', 'Порошок', %w[protyzastudni zharoznyzhuvalni], %w[лимон ягоди] ],
    [ 'Колдрекс', 'Парацетамол', 'Reckitt', 'Порошок', %w[protyzastudni], [ 'лимон', 'мед і лимон' ] ],
    [ 'Ринофлуїмуцил', 'Ацетилцистеїн', 'Sanofi', 'Спрей', %w[protyzastudni], [ '10 мл' ] ],
    [ 'Амоксицилін', 'Амоксицилін', 'Артеріум', 'Капсули', %w[antybiotyky], [ '250 мг', '500 мг' ], true ],
    [ 'Азитроміцин', 'Азитроміцин', 'KRKA', 'Таблетки', %w[antybiotyky], [ '250 мг', '500 мг' ], true ],
    [ 'Цефтріаксон', 'Цефтріаксон', 'Дарниця', 'Порошок', %w[antybiotyky], [ '1 г' ], true ],
    [ 'Лізиноприл', 'Лізиноприл', 'Gedeon Richter', 'Таблетки', %w[sertseve], [ '10 мг', '20 мг' ], true ],
    [ 'Кардіомагніл', 'Ацетилсаліцилова кислота', 'Teva', 'Таблетки', %w[sertseve], [ '75 мг', '150 мг' ] ],
    [ 'Аторвастатин', 'Аторвастатин', 'Pfizer', 'Таблетки', %w[sertseve], [ '10 мг', '20 мг', '40 мг' ], true ],
    [ 'Омепразол', 'Омепразол', 'Фармак', 'Капсули', %w[travlennia], [ '20 мг', '40 мг' ] ],
    [ 'Мезим', 'Панкреатин', 'Berlin-Chemie', 'Таблетки', %w[travlennia], [ '10 000 ОД', '20 000 ОД' ] ],
    [ 'Смекта', 'Смектит', 'Sanofi', 'Порошок', %w[travlennia dytiachi-liky], [ '3 г' ] ],
    [ 'Лоратадин', 'Лоратадин', 'Фармак', 'Таблетки', %w[alerhiia], [ '10 мг' ] ],
    [ 'Цетиризин', 'Цетиризин', 'KRKA', 'Краплі', %w[alerhiia dytiachi-liky], [ '10 мг/мл' ] ],
    [ 'Еріус', 'Дезлоратадин', 'Bayer', 'Сироп', %w[alerhiia], [ '0,5 мг/мл' ] ],
    [ 'Новопасит', 'Комбінований', 'Teva', 'Розчин', %w[zaspokiilyvi], [ '100 мл', '200 мл' ] ],
    [ 'Валеріана', 'Валеріана', 'Здоров’я', 'Таблетки', %w[zaspokiilyvi], [ '20 мг', '40 мг' ] ],
    [ 'Донорміл', 'Доксиламін', 'Sanofi', 'Таблетки', %w[snodiini], [ '15 мг' ], true ],
    [ 'Аскорутин', 'Аскорбінова кислота', 'Фармак', 'Таблетки', %w[vitamin-s multyvitaminy], [ '50 мг' ] ],
    [ 'Вітамін С', 'Аскорбінова кислота', 'Артеріум', 'Таблетки', %w[vitamin-s], [ '500 мг', '1000 мг' ] ],
    [ 'Аквадетрим', 'Колекальциферол', 'Здоров’я', 'Краплі', %w[vitamin-d dytiachi-liky], [ '15 000 МО/мл' ] ],
    [ 'Компливіт', 'Мультивітаміни', 'Фармак', 'Таблетки', %w[multyvitaminy], [ '30 шт.', '60 шт.' ] ],
    [ 'Магне B6', 'Магній', 'Sanofi', 'Таблетки', %w[mineraly], [ '470 мг' ] ],
    [ 'Кальцій D3', 'Кальцій', 'Novartis', 'Таблетки', %w[mineraly vitamin-d], [ '500 мг' ] ],
    [ 'Бепантен', 'Декспантенол', 'Bayer', 'Мазь', %w[tilo mama-i-dytyna], [ '5%' ] ],
    [ 'Гіалуронова сироватка', 'Гіалуронова кислота', 'Здоров’я', 'Гель', %w[oblychchia], [ '30 мл' ] ],
    [ 'Тонометр автоматичний', nil, 'Артеріум', 'Упаковка', %w[tonometry], [ 'на плече', 'на зап’ястя' ] ],
    [ 'Термометр електронний', nil, 'Дарниця', 'Упаковка', %w[termometry], %w[гнучкий стандартний] ],
    [ 'Нурофен для дітей', 'Ібупрофен', 'Reckitt', 'Сироп', %w[dytiachi-liky zharoznyzhuvalni], [ '100 мг/5 мл' ] ],
    [ 'Парацетамол дитячий', 'Парацетамол', 'Фармак', 'Супозиторії', %w[dytiachi-liky], [ '80 мг', '170 мг' ] ]
  ].freeze
end
