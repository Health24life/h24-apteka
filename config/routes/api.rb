# frozen_string_literal: true

# The public API the web and the app call.
namespace :api do
  namespace :v1 do
    post 'search', to: 'search#create'
    post 'goods/:id/drugstores', to: 'goods/drugstores#create', as: :goods_drugstores
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
