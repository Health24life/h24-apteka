# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::DescribePartnerStatus do
  def describe_status(**attributes) = described_class.call(build(:order, :submitted, **attributes))

  it 'shows a known status by its Ukrainian name', :aggregate_failures do
    result = describe_status(status_name: 'processed_by_pharmacy', status_comment: 'Ready')

    expect(result).to have_attributes(title: 'Оброблено в аптеці', comment: 'Ready', known: true)
  end

  it 'knows every status seen so far', :aggregate_failures do
    %w[created processed_by_pharmacy canceled].each do |name|
      expect(describe_status(status_name: name)).to have_attributes(known: true, title: be_present)
    end
  end

  it 'shows an unknown status as the partner wrote it, with the comment', :aggregate_failures do
    result = describe_status(status_name: 'awaiting_courier', status_comment: 'Courier is on the way')

    expect(result).to have_attributes(title: 'awaiting_courier', comment: 'Courier is on the way', known: false)
  end

  it 'does not turn a status into a state of its own' do
    titles = %w[awaiting_courier created].map { describe_status(status_name: it).title }

    expect(titles.uniq.size).to eq(2)
  end

  it 'copes with an order that has no status yet' do
    expect(describe_status(status_name: nil)).to have_attributes(title: nil, comment: nil, known: false)
  end

  it 'does not treat a status that is a path in the dictionary as a known one', :aggregate_failures do
    result = describe_status(status_name: 'x.y')

    expect(result).to have_attributes(title: 'x.y', known: false)
  end
end
