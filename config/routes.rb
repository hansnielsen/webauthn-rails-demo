Rails.application.routes.draw do
  root to: 'two_factor#index'

  resources :two_factor, only: [:new, :create, :destroy] do
    collection do
      get 'sign'
      post 'sign' => :validate
    end
  end
end
