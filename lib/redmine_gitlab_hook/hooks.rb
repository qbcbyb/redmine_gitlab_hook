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

      if user_name && password && remote_url && context[:project] && context[:project].identifier
        redmine_project_id = context[:project].identifier
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
            text_field_tag('git_project_filter', nil, :placeholder => "Search Filter") +
            select_tag('git_namespace', options_for_select([l('value_git_namespace_none')])) +
            tag('input', {value: l('genrate_gitlab_webhook'), type: 'button', id: 'btnWebHook', style: 'margin:0 0 0 5px;'}) +
            javascript_tag(js_content) + '</p>'
      end
    end
  end
end
