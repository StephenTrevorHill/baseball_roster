Rails.application.routes.draw do
  root 'teams#index'
  
  resources :teams, only: [:index, :show, :new, :create] do
    resources :players, only: [:show, :new, :create, :destroy]
  end
end
