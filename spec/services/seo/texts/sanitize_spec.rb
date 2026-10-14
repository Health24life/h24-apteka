# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Texts::Sanitize do
  def clean(html) = described_class.call(html).html

  it 'keeps the tags the front shows', :aggregate_failures do
    html = '<h2>Як забронювати</h2><p>Оберіть <strong>аптеку</strong> й <em>товар</em>.<br>Готово.</p>' \
           '<ul><li>Без передоплати</li></ul><ol><li>Крок</li></ol><blockquote>Цитата</blockquote><h3>Далі</h3>'

    expect(clean(html)).to eq(html)
    expect(described_class.call(html).changed).to be(false)
  end

  it 'drops other tags and attributes and keeps their text', :aggregate_failures do
    result = described_class.call('<p class="x">Знеболювальні <span style="color: red">засоби</span></p>')

    expect(result.html).to eq('<p>Знеболювальні засоби</p>')
    expect(result.changed).to be(true)
  end

  it 'drops scripts and styles with what is inside them' do
    expect(clean('<p>Знеболювальні <span class="x">засоби</span></p><script>alert(1)</script><style>p{}</style>'))
      .to eq('<p>Знеболювальні засоби</p>')
  end

  it 'drops an embedded frame and a picture' do
    expect(clean('<p>Текст</p><iframe src="https://e.com">x</iframe><img src="https://e.com/a.png">'))
      .to eq('<p>Текст</p>')
  end

  it 'keeps a link to a path of the section or to a site over HTTPS', :aggregate_failures do
    expect(clean('<a href="/katalog/liky">Ліки</a>')).to eq('<a href="/katalog/liky">Ліки</a>')
    expect(clean('<a href="https://h24.ua">Health24</a>')).to eq('<a href="https://h24.ua">Health24</a>')
  end

  it 'takes the address off any other link and keeps its text', :aggregate_failures do
    expect(clean('<a href="javascript:alert(1)">Тут</a>')).to eq('<a>Тут</a>')
    expect(clean('<a href="http://example.com">Тут</a>')).to eq('<a>Тут</a>')
    expect(clean('<a href="//evil.example">Тут</a>')).to eq('<a>Тут</a>')
  end

  it 'does not count a mere difference in markup as a change' do
    expect(described_class.call('<p>Рядок<br/>рядок</p>').changed).to be(false)
  end

  it 'leaves an empty text as it is' do
    expect(described_class.call(nil)).to have_attributes(html: nil, changed: false)
  end
end
