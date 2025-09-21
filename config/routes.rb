Rails.application.routes.draw do
  devise_for :users

  root to: "chats#index"  # dashboard as the homepage

  resources :calendar_events

  resources :attachments, only: [:index, :create, :destroy] do
    member do
      get :download
    end
  end
  resources :chats, only: [:index, :create]

  resources :records, only: [:index, :show, :create, :update, :destroy]
end