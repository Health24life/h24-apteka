# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NeutralWordingValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Text'

      attr_accessor :title

      validates :title, neutral_wording: true
    end
  end

  def valid?(title) = model.new(title:).valid?

  it 'accepts neutral wording', :aggregate_failures do
    expect(valid?('Нурофен 200 мг — інструкція із застосування')).to be(true)
    expect(valid?(nil)).to be(true)
  end

  it 'refuses every form of a call to buy', :aggregate_failures do
    %w[Купити купіть Купуйте купівля].each { expect(valid?("#{it} Нурофен")).to be(false) }
  end

  it 'refuses every form of the price', :aggregate_failures do
    [ 'Ціна Нурофену', 'Нурофен за найкращою ціною', 'порівняння цін' ].each { expect(valid?(it)).to be(false) }
  end

  it 'accepts words that only start the same', :aggregate_failures do
    expect(valid?('Цінні властивості вітамінів')).to be(true)
    expect(valid?('Купаж трав')).to be(true)
  end

  it 'names the words it found' do
    text = model.new(title: 'Купити за ціною виробника')
    text.validate

    expect(text.errors).to be_added(:title, :not_neutral, words: 'купити, ціною')
  end

  it 'follows the words of the locale' do
    allow(I18n).to receive(:t).and_call_original
    allow(I18n).to receive(:t).with('seo.forbidden_words', locale: :uk).and_return(%w[дешево])

    expect(valid?('Дешево і швидко')).to be(false)
  end
end
