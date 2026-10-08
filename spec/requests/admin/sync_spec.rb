# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sync journal' do
  let(:admin) { create(:admin_user) }
  let!(:provider) { create(:provider, code: 'pharmapoint', name: 'Pharmapoint') }
  let(:run) { create(:sync_run, :failed, provider:, kind: 'drugstores', processed_count: 3) }
  let(:order_log) do
    create(:provider_request_log, provider:, category: 'booking', http_method: 'POST',
                                  path: '/order/store-pick-up-order', request_body: order_body,
                                  response_body: { 'data' => { 'order_number' => '2E-2H-X4-K5' } })
  end

  def order_body
    { 'customer_first_name' => 'Олена', 'customer_phone_number' => '380501234567', 'customer_email' => 'olena@mail.ua',
      'drugstore_id' => 34_494, 'delivery' => { 'delivery_type_code' => 'PickUp', 'street' => 'Братиславська' } }
  end

  before { sign_in admin }

  describe 'runs' do
    it 'lists the runs and the pulls apart', :aggregate_failures do
      run
      create(:sync_run, :succeeded, provider:, kind: 'goods_groups', progress: { 'mode' => 'pull' })

      get admin_sync_runs_path

      expect(response.body).to include('Аптеки', 'Групи товарів', 'прогін', 'дотягування')
    end

    it 'filters out the pulls', :aggregate_failures do
      pull = create(:sync_run, :succeeded, provider:, kind: 'goods_groups', progress: { 'mode' => 'pull' })
      run

      get admin_sync_runs_path, params: { q: { mode_eq: 'full' } }

      expect(response.body).to include(admin_sync_run_path(run))
      expect(response.body).not_to include(admin_sync_run_path(pull))
    end

    it 'shows a run with its failures, masked, and a link to its requests', :aggregate_failures do
      create(:sync_run_failure, sync_run: run, message: 'call 380501234567', payload: { 'to' => 'olena@mail.ua' })

      get admin_sync_run_path(run)

      expect(response.body).to include('Catalog::Drugstore', 'call [masked]', '&quot;to&quot;: &quot;[masked]&quot;',
                                       'boom', "q%5Bsync_run_id_eq%5D=#{run.id}")
      expect(response.body).not_to include('olena@mail.ua', '380501234567')
    end
  end

  describe 'starting a run by hand' do
    it 'offers a button for each kind the schedule has on and none for the goods groups', :aggregate_failures do
      get admin_sync_runs_path

      expect(response.body).to include(start_admin_sync_runs_path(kind: 'drugstores'))
      expect(response.body).not_to include(start_admin_sync_runs_path(kind: 'goods_groups'))
      expect(response.body).to include('Вид вимкнено в розкладі')
    end

    it 'starts a run of a kind the schedule has on', :aggregate_failures do
      post start_admin_sync_runs_path, params: { kind: 'drugstores' }

      expect(response).to redirect_to(admin_sync_runs_path)
      expect(flash[:notice]).to eq('Прогін «Аптеки» поставлено в чергу.')
      expect(SyncRun.excluding_pulls.sole).to have_attributes(kind: 'drugstores', status: 'running')
    end

    it 'starts no second run of a kind that is running', :aggregate_failures do
      create(:sync_run, provider:, kind: 'categories', started_at: 1.minute.ago)

      post start_admin_sync_runs_path, params: { kind: 'categories' }

      expect(flash[:alert]).to eq('Прогін «Категорії» уже виконується — другий не запущено.')
      expect(SyncRun.count).to eq(1)
    end

    it 'refuses a kind the schedule has off, even asked past the page', :aggregate_failures do
      post start_admin_sync_runs_path, params: { kind: 'goods_groups' }

      expect(flash[:alert]).to eq('Вид «Групи товарів» вимкнено в розкладі — запуск недоступний.')
      expect(SyncRun.count).to eq(0)
    end
  end

  describe 'request log' do
    it 'masks the client in the bodies and keeps the order itself', :aggregate_failures do
      get admin_provider_request_log_path(order_log)

      expect(response.body).not_to include('Олена', '380501234567', 'olena@mail.ua', 'Братиславська')
      expect(response.body).to include('[masked]', '34494', 'PickUp', '2E-2H-X4-K5')
    end

    it 'masks a prescription number in the path, on the card and in the list', :aggregate_failures do
      recipe_log = create(:provider_request_log, provider:, path: '/e-health-recipe/0000-4942-TE9P-EXAA')

      get admin_provider_request_log_path(recipe_log)
      expect(response.body).to include('/e-health-recipe/[masked]')
      get admin_provider_request_logs_path
      expect(response.body).not_to include('0000-4942-TE9P-EXAA')
    end

    it 'keeps the stored request as it was' do
      expect { get admin_provider_request_log_path(order_log) }.not_to(change { order_log.reload.request_body })
    end

    it 'lists only the requests of a run when filtered by it', :aggregate_failures do
      own = create(:provider_request_log, provider:, sync_run: run)
      other = create(:provider_request_log, provider:)

      get admin_provider_request_logs_path, params: { q: { sync_run_id_eq: run.id } }

      expect(response.body).to include(admin_provider_request_log_path(own))
      expect(response.body).not_to include(admin_provider_request_log_path(other))
    end

    it 'ignores a filter on the contents of a request', :aggregate_failures do
      order_log
      other = create(:provider_request_log, provider:, path: '/goods-group/search')

      get admin_provider_request_logs_path, params: { q: { request_body_cont: '380501234567', path_cont: 'order' } }

      expect(response.body).to include(admin_provider_request_log_path(other),
                                       admin_provider_request_log_path(order_log))
    end
  end

  describe 'downloads' do
    %w[csv json xml].each do |format|
      it "gives no #{format} of the request log, the list or a card", :aggregate_failures do
        get admin_provider_request_logs_path(format:)
        expect(response).to redirect_to(admin_root_path)
        get admin_provider_request_log_path(order_log, format:)
        expect(response).to redirect_to(admin_root_path)
      end

      it "gives no #{format} of the runs" do
        get admin_sync_run_path(run, format:)

        expect(response).to redirect_to(admin_root_path)
      end
    end
  end
end
