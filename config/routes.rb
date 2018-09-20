RedmineApp::Application.routes.draw do
  match 'gitlab_hook', :to => 'gitlab_hook#index', :via => [:get, :post]
  post 'gitlab_hook_set', :to => 'gitlab_hook#setwebhook'
  get 'get_gitlab_projects/:filter', :to => 'gitlab_hook#getprojects'
  get 'oauth_gitlab', :to => 'gitlab_oauth#oauth_gitlab'
  get 'oauth2callback', :to => 'gitlab_oauth#oauth_gitlab_callback', :as => 'oauth_gitlab_callback'
end
