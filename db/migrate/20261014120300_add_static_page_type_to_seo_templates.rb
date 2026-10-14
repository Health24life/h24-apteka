class AddStaticPageTypeToSeoTemplates < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :seo_templates, "page_type IN ('home', 'category', 'goods', 'cart', 'order')",
                            name: 'seo_templates_page_type_check'
    add_check_constraint :seo_templates, "page_type IN ('home', 'category', 'goods', 'cart', 'order', 'static')",
                         name: 'seo_templates_page_type_check'
  end
end
