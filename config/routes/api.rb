# frozen_string_literal: true

# The public API the web and the app call.
namespace :api do
  namespace :v1 do
    post 'search', to: 'search#create'
    # «Мої товари» and «Мої аптеки» of the signed-in user; the id of the SKU or the drugstore names the record.
    namespace :favorites do
      resources :goods, only: %i[index update destroy], param: :goods_id
      resources :drugstores, only: %i[index update destroy], param: :drugstore_id
    end
    namespace :pillbox do
      resources :plans, only: :create
    end
    resources :goods, only: [] do
      resources :drugstores, only: :create, module: :goods
    end
    # A cart is an order in the cart state; its owner reaches it by the token in the path.
    resources :orders, only: %i[index create show destroy], param: :token do
      get :current, on: :collection
      scope module: :orders do
        resources :items, only: %i[create update destroy]
        resource :booking, only: :create
      end
    end
  end
end
