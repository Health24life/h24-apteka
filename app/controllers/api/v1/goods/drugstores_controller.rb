# frozen_string_literal: true

# The drugstores around the user that have a SKU, with its price there, for the user to pick the drugstore of the
# cart. Prices and stock are asked of the providers live, so a provider that does not answer is an error, not an empty
# list. A guest is served as a signed-in user is, save for the filter of «Мої аптеки», which needs an account.
class Api::V1::Goods::DrugstoresController < ApiController
  before_action :no_store

  rescue_from Catalog::Search::Invalid, with: ->(error) { render_error(error.code, status: :unprocessable_content) }

  def create
    body = params.to_unsafe_h
    only_favorites = only_favorites(body['only_favorites'])
    return render_error(:unauthorized, status: :unauthorized) if only_favorites && current_user_id.nil?

    goods = Orders::Offers::Nearby.find_goods(params[:goods_id])
    return render_error(:goods_not_found, status: :not_found) unless goods

    answer(Orders::Offers::Nearby.call(goods, **choice(body), user_id: current_user_id), only_favorites)
  end

  private

  # With the filter of «Мої аптеки» the answer also tells how many drugstores the filter alone hid, so the front can
  # tell «none of yours has it» from «none around has it».
  def answer(result, only_favorites)
    return refuse(result) if result.is_a?(Orders::Offers::Failure)
    return render json: { drugstores: render_drugstores(result) } unless only_favorites

    favorites = result.select(&:favorite)
    render json: { drugstores: render_drugstores(favorites), hidden_by_favorites: result.size - favorites.size }
  end

  def render_drugstores(rows) = Orders::Offers::NearbyDrugstoreBlueprint.render_as_hash(rows)

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

  def only_favorites(value)
    return false if value.nil?
    raise Catalog::Search::Invalid, :invalid_only_favorites unless [ true, false ].include?(value)

    value
  end

  def refuse(failure)
    return render_error(:drugstores_unavailable, status: :service_unavailable) unless failure.rate_limited?

    response.headers['Retry-After'] = failure.retry_after.to_s
    render_error(:drugstores_busy, status: :service_unavailable)
  end
end
