# frozen_string_literal: true

ActiveAdmin.register Order do
  menu priority: 15

  actions :index, :show
  config.batch_actions = false
  config.comments = false
  config.sort_order = 'id_desc'

  includes :delivery, :drugstore

  scope :sent, default: true, &:not_cart
  scope :cart
  scope :all

  filter :own_number
  filter :provider_order_number
  filter :customer_phone_eq, as: :string, label: proc { Order.human_attribute_name(:customer_phone_number) }
  filter :state, as: :select, collection: proc {
    %w[submitted submission_failed].map { |state| [ t("admin.orders.states.#{state}"), state ] }
  }
  filter :status_name_eq, as: :string, label: proc { Order.human_attribute_name(:status_name) }
  filter :drugstore, as: :tom_select, ajax: true
  filter :provider
  filter :created_at

  index download_links: false do
    id_column
    column :own_number
    column :created_at
    column(:state) { |order| t("admin.orders.states.#{order.state}") }
    column(:status_name) { |order| Orders::DescribePartnerStatus.call(order).title }
    column(:drugstore, sortable: false) do |order|
      order.cart? ? order.drugstore.name || order.drugstore.drugstore_legal_entity_name : order.drugstore_name
    end
    column(:customer, sortable: false) do |order|
      Orders::CustomerMask.person(order.customer_first_name, order.customer_last_name)
    end
    column(:customer_phone_number, sortable: false) { |order| Orders::CustomerMask.phone(order.customer_phone_number) }
    column(:delivery_type_code, sortable: false) do |order|
      order.delivery && t("admin.orders.delivery_types.#{order.delivery.delivery_type_code}")
    end
    actions
  end

  show do
    user = resource.user_id || t('admin.orders.guest')

    if resource.cart?
      attributes_table do
        row :id
        row(:state) { t('admin.orders.states.cart') }
        row :drugstore
        row :provider
        row(:user_id) { user }
        row :created_at
        row :updated_at
      end

      panel t('admin.orders.items') do
        table_for resource.items.includes(:goods) do
          column(:goods) { |item| auto_link(item.goods) }
          column :quantity
        end
      end
    else
      json = lambda do |value|
        next span(t('admin.request_logs.empty')) if value.blank?

        details do
          summary t('admin.request_logs.expand')
          pre JSON.pretty_generate(value)
        end
      end
      status = Orders::DescribePartnerStatus.call(resource)

      attributes_table do
        row :id
        row :own_number
        row :provider_order_number
        row :provider
        row(:state) { t("admin.orders.states.#{resource.state}") }
        row(:status_name) { status.title }
        row(:status_comment) { status.comment }
        row :cancel_reason
        row(:progress) { json.call(resource.progress) }
        row :provider_updated_at
        row :status_synced_at
        row :created_at
        row :updated_at
      end

      panel t('admin.orders.customer') do
        attributes_table_for resource do
          row :customer_last_name
          row :customer_first_name
          row :customer_middle_name
          row :customer_phone_number
          row :customer_email
          row :personal_data_consent_at
          row :register_account
          row(:user_id) { user }
        end
      end

      panel t('admin.orders.drugstore') do
        attributes_table_for resource do
          row :drugstore
          row :drugstore_name
          row :drugstore_address
          row :drugstore_phone
          row :provider_drugstore_external_id
        end
      end

      panel t('admin.orders.receipt') do
        attributes_table_for resource do
          row(:delivery_type_code) do
            resource.delivery && t("admin.orders.delivery_types.#{resource.delivery.delivery_type_code}")
          end
          row(:delivery_address) do
            address = resource.delivery&.address
            address && [ address.postal_code, address.city, address.street, address.building, address.post_office ]
              .compact_blank.join(', ')
          end
          row(:payment_type_code) do
            resource.payment && t("admin.orders.payment_types.#{resource.payment.payment_type_code}")
          end
        end
      end

      panel t('admin.orders.items') do
        table_for resource.items.includes(:goods) do
          column :name
          column :producer
          column :release_form
          column :quantity
          column :price
          column :total
          column(:goods) { |item| item.goods && auto_link(item.goods) }
        end
      end

      panel t('admin.orders.provider_payload') do
        json.call(resource.provider_payload)
      end
    end
  end

  controller do
    private

    # ActiveAdmin sorts by any column of the table named in the URL, bypassing Ransack, so ?order=token_asc would line
    # the orders up by a guest's key.
    def apply_sorting(chain)
      column = params[:order].to_s.sub(/_(?:asc|desc)\z/, '')
      params[:order] = active_admin_config.sort_order if params[:order].present? && Order::FILTERABLE.exclude?(column)
      super
    end
  end
end
