class AddFiltersToSeoRedirectsAndTemplates < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :seo_redirects, "page_type IN ('goods', 'category', 'static')",
                            name: 'seo_redirects_page_type_check'
    add_check_constraint :seo_redirects, "page_type IN ('goods', 'category', 'static', 'filter')",
                         name: 'seo_redirects_page_type_check'

    remove_check_constraint :seo_redirects,
                            "redirectable_type IN ('Catalog::Goods', 'Catalog::Category', 'Seo::StaticPage')",
                            name: 'seo_redirects_type_check'
    add_check_constraint :seo_redirects,
                         "redirectable_type IN ('Catalog::Goods', 'Catalog::Category', 'Seo::StaticPage', 'Seo::Filter')",
                         name: 'seo_redirects_type_check'

    remove_check_constraint :seo_templates, "page_type IN ('home', 'category', 'goods', 'cart', 'order', 'static')",
                            name: 'seo_templates_page_type_check'
    add_check_constraint :seo_templates,
                         "page_type IN ('home', 'category', 'goods', 'cart', 'order', 'static', 'filter')",
                         name: 'seo_templates_page_type_check'
  end
end
