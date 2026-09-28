# frozen_string_literal: true

ActiveAdmin.register AdminUser do
  config.batch_actions = false

  permit_params :email, :password, :password_confirmation, :is_active

  index do
    id_column
    column :email
    column :is_active
    column :created_at
    actions
  end

  filter :email
  filter :is_active
  filter :created_at

  # Spelled out rather than left to the ActiveAdmin default, which renders every column — including
  # encrypted_password.
  show do
    attributes_table do
      row :id
      row :email
      row :is_active
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :password
      f.input :password_confirmation
      own_record = f.object == current_admin_user
      f.input :is_active, input_html: { disabled: own_record },
                          hint: own_record ? 'You cannot deactivate your own account.' : nil
    end
    f.actions
  end

  controller do
    # Allow editing an admin without changing the password: drop blank password
    # params so Devise's :validatable does not reject the update.
    def update
      attrs = params[:admin_user]

      if attrs[:password].blank?
        attrs.delete(:password)
        attrs.delete(:password_confirmation)
      end

      # Belt to the disabled input's braces — a hand-crafted request must not sign its sender out.
      attrs.delete(:is_active) if resource == current_admin_user

      super
    end
  end
end
