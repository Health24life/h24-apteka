# frozen_string_literal: true

ActiveAdmin.register Seo::Version, as: 'SeoHistory' do
  menu parent: 'SEO', priority: 9

  actions :index
  config.batch_actions = false
  config.sort_order = 'created_at_desc'

  includes :author, :owner

  filter :author_id, as: :select, label: proc { Seo::Version.human_attribute_name(:author) },
                     collection: proc { AdminUser.order(:email).pluck(:email, :id) }
  filter :item_type, as: :select, label: proc { Seo::Version.human_attribute_name(:item_type) },
                     collection: proc { Seo::Version.distinct.order(:item_type).pluck(:item_type).map { [ it.constantize.model_name.human, it ] } }
  filter :created_at, label: proc { Seo::Version.human_attribute_name(:created_at) }

  index do
    column(t('admin.seo_history.at')) { |version| l(version.created_at, format: :long) }
    column(t('admin.seo_history.author')) { |version| seo_version_author(version) }
    column(t('admin.seo_history.page')) do |version|
      path = seo_admin_path(version.owner)
      path ? link_to(seo_record_name(version.owner), path) : version.owner_type
    end
    column(t('admin.seo_history.object')) { |version| seo_version_object(version) }
    column(t('admin.seo_history.changes')) { |version| render 'admin/seo_changes', version: }
  end
end
