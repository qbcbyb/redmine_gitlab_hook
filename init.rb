require_dependency 'redmine_gitlab_hook/hooks'

Redmine::Plugin.register :redmine_gitlab_hook do
  name 'Redmine GitLab Hook plugin'
  author 'zhangqiuyun@infohold.com.cn'
  description 'This plugin allows your Redmine installation to receive GitLab post-receive notifications'
  version '1.0.0'
  url 'https://github.com/qbcbyb/redmine_gitlab_hook'
  author_url 'https://github.com/qbcbyb'
  requires_redmine :version_or_higher => '2.3.0'

  settings :default => {
      :all_branches => 'yes',
      :prune => 'yes',
      :auto_create => 'yes',
      :fetch_updates => 'yes',
      :git_user_name => '',
      :git_user_password => '',
      :git_remote_url => '',
      :client_id => "",
      :client_secret => "",
      :oauth_authentification => false,
      :gitlab_api_v4 => false,
      :allowed_domains => "",
      :register_enable => false
  }, :partial => 'settings/gitlab_hook_settings'

  Redmine::MenuManager.map :account_menu do |menu|
    menu.delete :register
    menu.push :register, :register_path, :if => Proc.new {!User.current.logged? && Setting.self_registration? && Setting.plugin_redmine_gitlab_hook['register_enable']}
  end
end
