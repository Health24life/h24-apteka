# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Core::Medication::Inn do
  describe '.by_original' do
    it 'matches case-insensitively and ignores surrounding whitespace' do
      inn = create(:h24_core_inn, title_original: 'Paracetamol')

      expect(described_class.by_original('  PARACETAMOL ')).to contain_exactly(inn)
    end

    it 'puts the eHealth-backed row first among case variants' do
      plain = create(:h24_core_inn, title_original: 'ibuprofen', in_ehealth: false)
      ehealth = create(:h24_core_inn, title_original: 'Ibuprofen', in_ehealth: true)

      expect(described_class.by_original('ibuprofen').to_a).to eq([ ehealth, plain ])
    end

    it 'finds nothing for an unknown name' do
      expect(described_class.by_original('nonexistent')).to be_empty
    end
  end
end
