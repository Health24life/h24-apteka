# frozen_string_literal: true

# Serves the generated sitemap from the root of the API host, outside the versioned API: the front proxies its own
# /sitemap.xml and the parts here. Search engines need no session, so none is asked for.
class Seo::SitemapsController < ActionController::API
  def show
    name = params[:part] ? "sitemap-#{params[:part]}.xml" : Seo::Sitemaps::Generate::INDEX
    file = Seo::Sitemaps::Generate.current_dir.join(name)
    return head :not_found unless file.file?

    send_file file, type: 'application/xml', disposition: 'inline'
  end
end
