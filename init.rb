require_dependency 'redmine_gitlab_hook/hooks'

Redmine::Plugin.register :redmine_gitlab_hook do
  name 'Redmine GitLab Hook plugin'
  author 'zhangqiuyun@infohold.com.cn'
  description 'This plugin allows your Redmine installation to receive GitLab post-receive notifications'
  version '1.0.1'
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


end

Redmine::MenuManager.map :account_menu do |menu|
  menu.delete :register
  menu.push :register, :register_path, :if => Proc.new {!User.current.logged? && Setting.self_registration? && Setting.plugin_redmine_gitlab_hook['register_enable']}
end

User.class_eval do
  has_one :gitlab_refresh_token, lambda {where "action='gitlab_refresh_token'"}, :class_name => 'Token'
  has_one :gitlab_token, lambda {where "action='gitlab_token'"}, :class_name => 'Token'

  def gitlab_refresh_token_value
    gitlab_refresh_token.try(:value)
  end

  def gitlab_token_value
    gitlab_token.try(:value)
  end

  def gitlab_refresh_token= (arg)
    token = gitlab_refresh_token || build_gitlab_refresh_token(:action => 'gitlab_refresh_token')
    token.value = arg
    token.save
  end

  def gitlab_token= (arg)
    token = gitlab_token || build_gitlab_token(:action => 'gitlab_token')
    token.value = arg
    token.save
  end
end

Setting.class_eval do

  def self.plugin_redmine_gitlab_hook= (setting)
    self[:plugin_redmine_gitlab_hook] = setting

    user_name = setting['git_user_name']
    password = setting['git_user_password']
    remote_url = setting['git_remote_url']
    if user_name && password && remote_url
      system "git config --global user.name #{user_name}"
      system "git config --global user.password #{password}"
      system "git config --global credential.helper store"

      encoded_user_name = URI.encode_www_form_component(user_name)
      encoded_password = URI.encode_www_form_component(password)
      uri = URI.parse(remote_url)
      uri.userinfo = "#{encoded_user_name}:#{encoded_password}"
      remote_url = uri.to_s
      system "echo \"#{remote_url}\" > ~/.git-credentials"
    end
  end
end
