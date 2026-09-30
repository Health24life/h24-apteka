# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeekWorkingHoursValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      def self.name = 'Schedule'

      attribute :hours
      validates :hours, week_working_hours: true
    end
  end

  def valid?(value) = model.new(hours: value).valid?

  it 'accepts seven days of strings or nils', :aggregate_failures do
    expect(valid?([ '08:00-21:00' ] * 7)).to be(true)
    expect(valid?([ nil, '09:00-18:00', nil, nil, nil, nil, 'за домовленістю' ])).to be(true)
  end

  it 'accepts an empty schedule, meaning the provider sent none' do
    expect(valid?([])).to be(true)
  end

  it 'refuses a wrong number of days', :aggregate_failures do
    expect(valid?([ '08:00-21:00' ] * 6)).to be(false)
    expect(valid?([ '08:00-21:00' ] * 8)).to be(false)
  end

  it 'refuses non-string days and non-arrays', :aggregate_failures do
    expect(valid?([ 1, 2, 3, 4, 5, 6, 7 ])).to be(false)
    expect(valid?(([ '08:00-21:00' ] * 6) + [ { 'from' => 8 } ])).to be(false)
    expect(valid?(nil)).to be(false)
    expect(valid?('08:00-21:00')).to be(false)
  end
end
