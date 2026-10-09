# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Customers::Mask do
  describe '.phone' do
    it 'keeps the first three and the last four digits' do
      expect(described_class.phone('380501234567')).to eq('380*****4567')
    end

    it 'hides a value too short to keep anything' do
      expect(described_class.phone('1234567')).to eq('*******')
    end

    it 'gives nothing for no phone', :aggregate_failures do
      expect(described_class.phone(nil)).to be_nil
      expect(described_class.phone('')).to be_nil
    end
  end

  describe '.person' do
    it 'keeps the first name and the initial of the last one' do
      expect(described_class.person('Іван', 'Коваленко')).to eq('Іван К.')
    end

    it 'gives the first name alone when there is no last name', :aggregate_failures do
      expect(described_class.person('Іван', nil)).to eq('Іван')
      expect(described_class.person(' Іван ', '  ')).to eq('Іван')
    end

    it 'gives nothing without a first name', :aggregate_failures do
      expect(described_class.person(nil, 'Коваленко')).to be_nil
      expect(described_class.person(' ', 'Коваленко')).to be_nil
    end
  end
end
