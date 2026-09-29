# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'db/seeds.rb' do # rubocop:disable RSpec/DescribeClass
  def run_seeds
    load Rails.root.join('db/seeds.rb')
  end

  it 'creates the Pharmapoint provider', :aggregate_failures do
    run_seeds

    provider = Provider.find_by!(code: 'pharmapoint')
    expect(provider).to be_external
    expect(provider).to have_attributes(active: true, supports_e_recipe: true, supports_delivery: false)
  end

  it 'is idempotent' do
    run_seeds

    expect { run_seeds }.not_to change(Provider, :count)
  end

  it 'keeps a switch made in the admin panel' do
    run_seeds
    Provider.find_by!(code: 'pharmapoint').update!(active: false)

    run_seeds

    expect(Provider.find_by!(code: 'pharmapoint')).not_to be_active
  end
end
