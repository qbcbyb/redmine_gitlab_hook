module RedmineGitlabHook
  class Hooks < Redmine::Hook::ViewListener
    def view_account_login_bottom(context = {})
      context[:controller].send(:render_to_string, {
          :partial => "hooks/view_account_oauth_login_bottom",
          :locals => context})
    end

    def view_projects_form(context = {})
      setting = Setting.plugin_redmine_gitlab_hook


      user_name = setting['git_user_name']
      password = setting['git_user_password']
      remote_url = setting['git_remote_url']

      if user_name && password && remote_url && context[:project] && context[:project].id
        redmine_project_id = context[:project].id
        js_content = <<EOF
$(function(){
  var filterItem=$('#git_project_filter');
  var selectItem=$('#git_namespace');
  var queryProjects=function(){$.get('/get_gitlab_projects/%20'+filterItem.val(),function(res){
      selectItem.children('option:gt(0)').remove();
      if(!res||!(res instanceof Array)){
        console.log(res);
        return;
      }
      res.forEach(function(opt){
        selectItem.append($(`<option value="${opt.id}">${opt.path_with_namespace}</option>`))
      });
    });
  };
  filterItem.change(queryProjects);
  filterItem.keypress(function(e){if(e.keyCode==13){e.preventDefault();queryProjects();}});
  queryProjects();
  $('#btnWebHook').click(function(){
    if(selectItem[0].selectedIndex<1){
      alert('Choose namespace please!');
      return;
    }
    $.post('#{gitlab_hook_set_path}',{git_namespace:selectItem.val(),redmine_project_id:'#{redmine_project_id}'},function(result) {
      alert(result.message);
    });
  });
});
EOF
        '<p style="line-height: 34px;vertical-align: middle;">' + content_tag(:label, l('field_git_namespace')) +
            text_field_tag('git_project_filter') +
            select_tag('git_namespace', options_for_select([l('value_git_namespace_none')]), style: 'height:20px;') +
            tag('input', {value: l('genrate_gitlab_webhook'), type: 'button', id: 'btnWebHook', style: 'height:20px;margin:0 0 0 5px;'}) +
            javascript_tag(js_content) + '</p>'
      end
    end
  end
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
    self.[]= :plugin_redmine_gitlab_hook, setting

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
