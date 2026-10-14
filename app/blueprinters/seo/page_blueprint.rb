# frozen_string_literal: true

class Seo::PageBlueprint < Blueprinter::Base
  fields :status, :location, :title, :description, :h1, :robots, :seo_text, :content

  field :breadcrumbs do |page|
    page.breadcrumbs.map { { name: it.name, path: it.path } }
  end
end
