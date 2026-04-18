# frozen_string_literal: true

Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "bin/rails routes".
  root to: "main#index"

  post "/webhooks/aws/sns", to: "aws_sns_notifications#create"

  resources :teachers do
    post "upload_file", on: :member
    resource :email_address, only: [:create]
    delete "email_addresses/:id", to: "email_addresses#destroy", as: :delete_email_address
    member do
      post :resend_welcome_email
      post :validate
      post :deny
      post :request_info
      post :sync_mailbluster
      delete "remove_file", to: "teachers#remove_file"
    end
    collection do
      post :import
      get :cross_filter_search
      get :deliverability_issues
      post :sync_all_mailbluster
    end
  end
  resources :schools
  resources :pages, param: :url_slug
  resources :email_templates, except: [:show]
  resources :professional_developments do
    resources :pd_registrations, except: [:show]
  end

  get    "/login",  to: "sessions#new",     as: "login"
  delete "/logout", to: "sessions#destroy", as: "logout"
  get "/auth/:provider/callback", to: "sessions#omniauth_callback", as: "omniauth_callback"
  get "/auth/failure", to: "sessions#omniauth_failure", as: "omniauth_failure"

  get "/dashboard", to: "main#dashboard", as: "dashboard"

  get "merge/:from/:into/preview", to: "merge#preview", as: "preview_merge"
  patch "merge/:from/:into/execute", to: "merge#execute", as: "merge"

  get "school_merge/:from/:into/preview", to: "merge#school_preview", as: "preview_school_merge"
  patch "school_merge/:from/:into/execute", to: "merge#school_execute", as: "school_merge"
end
