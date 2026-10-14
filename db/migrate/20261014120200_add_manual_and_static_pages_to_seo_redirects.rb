class AddManualAndStaticPagesToSeoRedirects < ActiveRecord::Migration[8.1]
  def change
    add_column :seo_redirects, :manual, :boolean, null: false, default: false

    remove_check_constraint :seo_redirects, "page_type IN ('goods', 'category')", name: 'seo_redirects_page_type_check'
    add_check_constraint :seo_redirects, "page_type IN ('goods', 'category', 'static')",
                         name: 'seo_redirects_page_type_check'

    remove_check_constraint :seo_redirects, "redirectable_type IN ('Catalog::Goods', 'Catalog::Category')",
                            name: 'seo_redirects_type_check'
    add_check_constraint :seo_redirects, "redirectable_type IN ('Catalog::Goods', 'Catalog::Category', 'Seo::StaticPage')",
                         name: 'seo_redirects_type_check'
  end
end
