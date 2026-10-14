# frozen_string_literal: true

# The SEO filters of the front: the selections a category or the home page of the section shows, and the page of one
# filter by its current address. Only published filters that are not removed are there.
class Api::V1::FiltersController < ApiController
  CATEGORY_ID = /\A[1-9]\d*\z/

  def index
    category_id = params[:category_id].presence
    unless category_id.nil? || (category_id.is_a?(String) && category_id.match?(CATEGORY_ID))
      return render_error(:invalid_category_id, status: :unprocessable_content)
    end

    filters = scope.where(category_id: category_id&.to_i).order(:position, :id)
    render json: { filters: Seo::FilterBlueprint.render_as_hash(filters, view: :list) }
  end

  # The address, not the id: the front opens the page by its path, and an old address is redirected before it asks.
  def show
    filter = scope.find_by(slug: params[:id].to_s.downcase)
    return render_error(:filter_not_found, status: :not_found) unless filter

    render json: Seo::FilterBlueprint.render(filter, view: :card)
  end

  private

  def scope = Seo::Filter.listed
end
