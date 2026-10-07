# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'a run over the drugstore directory' do # rubocop:disable RSpec/DescribeClass
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:run) { SyncRun.where(kind: 'drugstores').excluding_pulls.last }
  let(:points) do
    [ Pharmapoint::Config::Point.new(latitude: 50.45, longitude: 30.52, radius: 1000),
      Pharmapoint::Config::Point.new(latitude: 49.99, longitude: 36.23, radius: 1000) ]
  end
  let(:any_point) { hash_including({}) }

  def sync = run_jobs { Catalog::Sync::StartWorker.perform_async('drugstores') }

  def stub_points(fixture = 'drugstores')
    stub_pharmapoint('drugstore', fixture:, query: { latitude: '50.45', longitude: '30.52', radius: '1000' })
    stub_pharmapoint('drugstore', fixture:, query: { latitude: '49.99', longitude: '36.23', radius: '1000' })
    stub_pharmapoint('drugstore/38628', fixture: 'drugstore')
    stub_pharmapoint('drugstore/38629', body: '{"data":[]}')
  end

  # Answers every search with the fixture list in which the drugstore at the index has its fields changed.
  def stub_list_with(index, changes)
    body = JSON.parse(pharmapoint_fixture('drugstores'))
    body['data'][index].merge!(changes)
    stub_pharmapoint('drugstore', body: body.to_json, query: any_point)
  end

  before do
    use_pharmapoint_config(search_points: points)
    stub_points
  end

  it 'saves each drugstore once even when two points both list it', :aggregate_failures do
    sync

    expect(run).to have_attributes(status: 'succeeded', failed_count: 0)
    expect(Catalog::Drugstore.count).to eq(2)
  end

  it 'saves the legal entity, the address with coordinates, the week schedule and the brand', :aggregate_failures do
    sync

    drugstore = Catalog::Drugstore.find_linked(provider, '38629')
    expect(drugstore).to have_attributes(drugstore_legal_entity_code: '01234567', work_with_reimbursement: false)
    expect(drugstore.address).to have_attributes(address: 'м. Київ, вул. Хрещатик, 1', latitude: 50.4501)
    expect(drugstore.brand.name).to eq('Аптеки ТАС')
  end

  it 'completes a drugstore the list gives in part from its own record', :aggregate_failures do
    sync

    drugstore = Catalog::Drugstore.find_linked(provider, '38628')
    expect(drugstore).to have_attributes(name: 'Аптека №2369, "Подорожник"', ext_drugstore_id: '2369',
                                         incomplete: false)
  end

  it 'keeps a drugstore incomplete while its own record cannot be read' do
    sync

    expect(Catalog::Drugstore.find_linked(provider, '38629').incomplete).to be(true)
  end

  it 'lets a list entry fill in nothing the full record already has' do
    2.times { sync }

    expect(Catalog::Drugstore.find_linked(provider, '38628'))
      .to have_attributes(name: 'Аптека №2369, "Подорожник"', incomplete: false)
  end

  it 'does not read the distance and the working hours of today into the directory' do
    sync

    expect(Catalog::Drugstore.column_names).not_to include('distance', 'working_hours')
  end

  describe 'when a drugstore comes without coordinates' do
    before do
      sync
      stub_list_with(0, 'coordinates' => {}, 'phone' => '000')
      sync
    end

    it 'logs that drugstore' do
      expect(run.failures.pluck(:entity_type, :external_id, :error_class))
        .to include([ 'Catalog::Drugstore', '38628', 'Catalog::Sync::MissingData' ])
    end

    it 'keeps the earlier one as it was' do
      expect(Catalog::Drugstore.find_linked(provider, '38628').phone).to eq('(093) 087-41-68')
    end
  end

  it 'does not take a drugstore off the shelf when it leaves the list, as the directory is not covered in full' do
    sync
    stub_pharmapoint('drugstore', body: { data: [] }.to_json, query: any_point)

    sync

    expect(Catalog::Drugstore.where(withdrawn: true)).to be_empty
  end

  it 'fails the run when no search points are configured', :aggregate_failures do
    use_pharmapoint_config(search_points: [])

    sync

    expect(run).to have_attributes(status: 'failed')
    expect(WebMock).not_to have_requested(:get, /partner.test/)
  end

  it 'rejects a legal entity code of the wrong shape as a failure of that drugstore only', :aggregate_failures do
    stub_list_with(1, 'legal_entity_code' => '12')
    sync

    expect(run.failures.pluck(:external_id)).to include('38629')
    expect(Catalog::Drugstore.find_linked(provider, '38628')).to be_present
  end
end
