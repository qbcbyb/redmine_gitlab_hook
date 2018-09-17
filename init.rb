require 'redmine'

Redmine::Plugin.register :redmine_gitlab_hook do
  name 'Redmine GitLab Hook plugin'
  author 'zhangqiuyun@infohold.com.cn'
  description 'This plugin allows your Redmine installation to receive GitLab post-receive notifications'
  version '0.2.2'
  url 'https://github.com/qbcbyb/redmine_gitlab_hook'
  author_url 'https://github.com/qbcbyb'
  requires_redmine :version_or_higher => '2.3.0'

  settings :default => {:all_branches => 'yes', :prune => 'yes', :auto_create => 'yes', :fetch_updates => 'yes'}, :partial => 'settings/gitlab_hook_settings'
end

def update_git_global_config
  if self.name == 'plugin_redmine_gitlab_hook'
    setting = Setting.plugin_redmine_gitlab_hook
    puts 'hello'
    # system "git config --global user.name=#{}"
    # system "git config --global user.password=#{}"
    # .after_save :update_git_global_config
  end
end

Setting.after_save :update_git_global_config
