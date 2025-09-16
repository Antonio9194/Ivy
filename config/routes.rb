Rails.application.routes.draw do
  get 'attachments/index'
  get 'attachments/create'
  devise_for :users

  root to: "chats#index"  # dashboard as the homepage

resources :attachments, only: [:index, :create]
resources :chats, only: [:index, :create]

  resources :records, only: [:index, :show, :create, :update, :destroy]
end