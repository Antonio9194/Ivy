Rails.application.routes.draw do
  devise_for :users

  root to: "chats#index"  # dashboard as the homepage

  resources :chats, only: [:index, :create] do
    resources :attachments, only: [:create]
  end

  resources :records, only: [:index, :show, :create, :update, :destroy]
end