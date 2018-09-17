require 'redmine'

Redmine::Plugin.register :redmine_gitlab_hook do
  name 'Redmine GitLab Hook plugin'
  author 'zhangqiuyun@infohold.com.cn'
  description 'This plugin allows your Redmine installation to receive GitLab post-receive notifications'
  version '0.2.2'
  url 'https://github.com/qbcbyb/redmine_gitlab_hook'
  author_url 'https://github.com/qbcbyb'
  requires_redmine :version_or_higher => '2.3.0'

  settings :default => {
      :all_branches => 'yes',
      :prune => 'yes',
      :auto_create => 'yes',
      :fetch_updates => 'yes',
      :git_user_name => '',
      :git_user_password => ''
  }, :partial => 'settings/gitlab_hook_settings'
end

Setting.class_eval do
  def self.plugin_redmine_gitlab_hook= (setting)
    self.[]= :plugin_redmine_gitlab_hook, setting
    system "git config --global user.name #{setting['git_user_name']}"
    system "git config --global user.password #{setting['git_user_password']}"
  end
end
