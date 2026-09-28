# frozen_string_literal: true

require 'sidekiq/web'
require 'sidekiq/cron/web'
require 'sidekiq-status/web'

Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config

  # Mounted before the Active Admin routes so /admin/sidekiq is served by Sidekiq::Web, not Active Admin.
  authenticate :admin_user do
    mount Sidekiq::Web => '/admin/sidekiq'
  end

  ActiveAdmin.routes(self)

  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_SWAGGER', false))
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
