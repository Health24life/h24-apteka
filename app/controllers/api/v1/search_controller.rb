# frozen_string_literal: true

# The search of goods for the web and the app. It always asks the providers live and never the local catalog, so a
# provider that does not answer is an error of the search, not an empty list. A guest is served as a signed-in user is.
class Api::V1::SearchController < ApiController
  before_action :no_store, only: :create

  rescue_from Catalog::Search::Invalid, with: ->(error) { render_error(error.code, status: :unprocessable_content) }

  def create
    queries = Catalog::Search::Queries::Build.call(params.to_unsafe_h['queries'])
    results = Catalog::Search::Run.call(queries, user_id: current_user_id)
    return refuse(results) if results.all?(&:unavailable?)

    render json: Catalog::Search::ResponseBlueprint.render_as_hash({ results: })
  end

  private

  def refuse(results)
    return render_error(:search_unavailable, status: :service_unavailable) unless results.all?(&:busy?)

    response.headers['Retry-After'] = results.filter_map(&:retry_after).min.to_s
    render_error(:search_busy, status: :service_unavailable)
  end
end
