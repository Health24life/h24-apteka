# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Customers::PhoneNormalizer do
  it 'brings a number written in any usual way to the stored form', :aggregate_failures do
    [ '380501234567', '+380501234567', '+38 (050) 123-45-67', '38 050 123 45 67', '0501234567', '050 123-45-67' ]
      .each { expect(described_class.call(it)).to eq('380501234567') }
  end

  it 'gives nothing for a part of a number or for something else', :aggregate_failures do
    [ '4567', '50123456', '38050123456', '3805012345678', '80501234567', '1501234567', 'phone', '', nil ]
      .each { expect(described_class.call(it)).to be_nil }
  end
end
