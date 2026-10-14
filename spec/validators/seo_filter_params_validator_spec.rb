# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeoFilterParamsValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Selection'

      attr_accessor :params

      validates :params, seo_filter_params: true
    end
  end

  def errors_of(params) = model.new(params:).tap(&:validate).errors

  let(:form) { create(:catalog_goods_form) }
  let(:category) { create(:catalog_category) }

  it 'accepts known parameters with ids of records that exist' do
    params = { 'category_id' => [ category.id ], 'form_id' => [ form.id ],
               'child_restriction_id' => [ create(:catalog_goods_restriction).id ],
               'producer_id' => [ create(:catalog_producer).id ] }

    expect(errors_of(params)).to be_empty
  end

  it 'accepts no parameters at all' do
    expect(errors_of({})).to be_empty
  end

  it 'refuses something that is not a set of parameters' do
    expect(errors_of([ form.id ]).details[:params]).to include(error: :not_an_object)
  end

  it 'refuses a parameter the catalog search does not have and names it' do
    errors = errors_of({ 'price_max' => [ 100 ] })

    expect(errors.details[:params]).to include(error: :unknown_param, param: 'price_max')
  end

  it 'refuses an id that is not in the catalog and names the parameter' do
    errors = errors_of({ 'producer_id' => [ 999_999 ] })

    expect(errors.details[:params]).to include(error: :missing_param_values, param: 'producer_id')
  end

  it 'refuses values that are not a non-empty list of distinct positive ids', :aggregate_failures do
    [ [], form.id, [ form.id.to_s ], [ form.id, form.id ], [ 0 ], [ -form.id ] ].each do |ids|
      expect(errors_of({ 'form_id' => ids }).details[:params])
        .to include(error: :invalid_param_values, param: 'form_id')
    end
  end

  it 'says in Ukrainian which parameter is wrong' do
    errors = errors_of({ 'price_max' => [ 100 ] })

    expect(errors.full_messages_for(:params).join).to include('price_max')
  end
end
