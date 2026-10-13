# frozen_string_literal: true

class Api::V1::Seo::PagesController < ApiController
  PATH_LIMIT = 2048

  def show
    path = params[:path]
    return render_error(:invalid_path, status: :unprocessable_content) unless page_path?(path)

    render json: Seo::PageBlueprint.render(Seo::Pages::Describe.call(path))
  end

  private

  def page_path?(path) = path.is_a?(String) && path.start_with?('/') && path.length <= PATH_LIMIT
end
