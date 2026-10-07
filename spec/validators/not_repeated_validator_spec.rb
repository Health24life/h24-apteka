# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotRepeatedValidator do
  subject(:model) do
    Class.new do
      include ActiveModel::Model

      def self.name = 'Line'

      attr_accessor :goods_id, :others

      validates :goods_id, not_repeated: { among: ->(line) { line.others } }
    end
  end

  def line(goods_id, others = [])
    model.new(goods_id:, others:)
  end

  it 'accepts a value no other record has', :aggregate_failures do
    expect(line(1)).to be_valid
    expect(line(1, [ line(2), line(3) ])).to be_valid
  end

  it 'refuses a value another record already has', :aggregate_failures do
    repeated = line(1, [ line(2), line(1) ])

    expect(repeated).not_to be_valid
    expect(repeated.errors).to be_added(:goods_id, :repeated)
  end

  it 'does not count the record itself among the others' do
    own = line(1)
    own.others = [ own, line(2) ]

    expect(own).to be_valid
  end

  it 'leaves a missing value to the presence checks' do
    expect(line(nil, [ line(nil) ])).to be_valid
  end

  it 'words the refusal in the locale files' do
    repeated = line(1, [ line(1) ]).tap(&:validate)

    expect(repeated.errors.full_messages.join).not_to match(/translation missing/i)
  end
end
