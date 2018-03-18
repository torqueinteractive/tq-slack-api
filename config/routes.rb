Rails.application.routes.draw do
  root 'api#index'

  scope :api do
    get '/', to: 'api#index'
    get '/enroll', to: 'api#enroll'
    get '/success', to: 'api#success'
    get '/view-files', to: 'api#view_files'
    get '/get-file-count', to: 'api#get_file_count'
    post '/get-file-count', to: 'api#get_file_count'
    post '/destroy-files', to: 'api#destroy_files'
    post '/manage-interactions', to: 'api#manage_interactions'
  end
end
