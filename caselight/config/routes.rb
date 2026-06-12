require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users

  root "dashboard#show"

  # Section 1: Search
  get "research", to: "research#index"
  resources :saved_searches, only: [:index, :create, :destroy] do
    member { post :toggle_alerts }
  end

  # Section 2: Document reader
  resources :documents, only: [:show], param: :slug do
    member do
      post :pin
      delete :unpin
      get :cite
      get :download
    end
    resources :annotations, only: [:create, :destroy], shallow: true
    resource :citator, only: [:show], controller: "citators" do
      get :graph
    end
  end

  # Section 3: Citation analysis
  get "citations", to: "citators#index"
  resources :topics, only: [:index, :show]

  # Section 4: History / timeline
  get "history", to: "history#index"
  delete "history", to: "history#clear"

  # Section 5: Matters / folders workspace
  resources :matters do
    member do
      post :archive
      post :unarchive
      post :trash
      post :restore
    end
  end
  resources :folders, except: [:edit] do
    member do
      post :archive
      post :trash
      post :restore
    end
  end
  resources :folder_items, only: [:create, :destroy]

  # Section 6: Documents (uploads) + brief analyzer
  resources :uploads, controller: "uploaded_documents" do
    member do
      post :archive
      post :trash
      post :restore
      post :reprocess
    end
    resources :brief_analyses, only: [:create, :show] do
      member { get :export }
    end
  end

  # Drafting
  resources :drafts do
    collection { post :generate }
    member do
      post :archive
      post :trash
      post :restore
    end
  end

  # AI research assistant
  resources :ai_conversations, only: [:index, :show, :create] do
    resources :ai_messages, only: [:create]
  end

  # Alerts bell
  resources :notifications, only: [:index] do
    member { post :mark_read }
    collection { post :mark_all_read }
  end

  # Settings, archive, trash
  get "settings", to: "settings#show"
  patch "settings", to: "settings#update"
  patch "settings/ai", to: "settings#update_ai", as: :settings_ai
  get "help", to: "help#show"

  get "archive", to: "trash#archive_index", as: :archive
  get "trash", to: "trash#index", as: :trash
  delete "trash/empty", to: "trash#empty", as: :empty_trash

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
