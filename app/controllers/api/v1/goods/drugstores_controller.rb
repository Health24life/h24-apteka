# frozen_string_literal: true

# The drugstores around the user that have a SKU, with its price there, for the user to pick the drugstore of the
# cart. Prices and stock are asked of the providers live, so a provider that does not answer is an error, not an empty
# list. A guest is served as a signed-in user is.
class Api::V1::Goods::DrugstoresController < ApiController
  before_action :no_store

  rescue_from Catalog::Search::Invalid, with: ->(error) { render_error(error.code, status: :unprocessable_content) }

  def create
    goods = Orders::Offers::Nearby.find_goods(params[:id])
    return render_error(:goods_not_found, status: :not_found) unless goods

    result = Orders::Offers::Nearby.call(goods, **choice(params.to_unsafe_h), user_id: current_user_id)
    return refuse(result) if result.is_a?(Orders::Offers::Failure)

    render json: { drugstores: Orders::Offers::NearbyDrugstoreBlueprint.render_as_hash(result) }
  end

  private

  # Where to look, the order and the filter the front asked for.
  def choice(body)
    {
      location: Catalog::Search::Locations::Build.call(body['location'], code: :invalid_location),
      sort: sort(body['sort']),
      reimbursement: reimbursement(body['work_with_reimbursement'])
    }
  end

  def sort(value)
    return 'price' if value.nil?
    raise Catalog::Search::Invalid, :invalid_sort unless Orders::Offers::Nearby::SORTS.include?(value)

    value
  end

  def reimbursement(value)
    return false if value.nil?
    raise Catalog::Search::Invalid, :invalid_reimbursement unless [ true, false ].include?(value)

    value
  end

  def refuse(failure)
    return render_error(:drugstores_unavailable, status: :service_unavailable) unless failure.rate_limited?

    response.headers['Retry-After'] = failure.retry_after.to_s
    render_error(:drugstores_busy, status: :service_unavailable)
  end
end
