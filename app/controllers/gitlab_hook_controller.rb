require 'json'

class GitlabHookController < ApplicationController

  GIT_BIN = Redmine::Configuration[:scm_git_command] || 'git'
  # skip_before_filter :verify_authenticity_token, :check_if_login_required
  (skip_before_filter :verify_authenticity_token, :check_if_login_required) if ENV['RAILS_ENV'] == 'production'

  def getprojects
    gitlab_api_v4 = Setting.plugin_redmine_gitlab_hook['gitlab_api_v4']
    remote_url = Setting.plugin_redmine_gitlab_hook['git_remote_url']
    gitlab_token_value = User.current.try('gitlab_token_value')

    filter = params[:filter].strip
    path = unless gitlab_api_v4
             "/api/v3/projects#{('/search/' + filter) unless filter.empty?}?access_token=#{gitlab_token_value}"
           else
             "/api/v4/projects?access_token=#{gitlab_token_value}#{('&search=' + filter) unless filter.empty?}"
           end
    response = Net::HTTP.get(URI.join(remote_url, path))
    render(:json => JSON.parse(response.to_s))
  end

  def setwebhook
    host_name = Setting.host_name
    protocol = Setting.protocol
    sys_api_key = Setting.sys_api_key
    gitlab_api_v4 = Setting.plugin_redmine_gitlab_hook['gitlab_api_v4']
    remote_url = Setting.plugin_redmine_gitlab_hook['git_remote_url']
    git_project_id = params[:git_namespace]
    redmine_project_id = params[:redmine_project_id]

    gitlab_token_value = User.current.try('gitlab_token_value')

    gitlab_api_version = gitlab_api_v4 ? 4 : 3

    response = Net::HTTP.get(URI.join(remote_url, "/api/v#{gitlab_api_version}/projects/#{git_project_id}/hooks?access_token=#{gitlab_token_value}"))
    hooks = JSON.parse(response.to_s)

    hooks.each do |hook|
      if hook['url'].include?(host_name)
        return render(:json => {success: false, message: "webhook exist"})
      end
    end

    response = Net::HTTP.post_form(URI.join(remote_url, "/api/v#{gitlab_api_version}/projects/#{git_project_id}/hooks?access_token=#{gitlab_token_value}"), {
        id: git_project_id,
        url: "#{protocol}://#{host_name}/gitlab_hook?project_id=#{redmine_project_id}&key=#{sys_api_key}",
        push_events: true,
        merge_requests_events: true,
        tag_push_events: true,
        enable_ssl_verification: false
    })
    result = JSON.parse(response.body)
    result['message'] = "Add Success"
    render(:json => result)
  end

  def index
    if request.post?
      repository = find_repository
      p repository.inspect
      git_success = true
      if repository
        # Fetch the changes from GitLab
        if Setting.plugin_redmine_gitlab_hook['fetch_updates'] == 'yes'
          git_success = update_repository(repository)
        end
        if git_success
          # Fetch the new changesets into Redmine
          repository.fetch_changesets
          render(:text => 'OK', :status => :ok)
        else
          render(:text => "Git command failed on repository: #{repository.identifier}!", :status => :not_acceptable)
        end
      end
    else
      raise ActionController::RoutingError.new('Not Found')
    end
  end


  private

  # Executes shell command. Returns true if the shell command exits with a success status code
  def exec(command)
    logger.debug {"GitLabHook: Executing command: '#{command}'"}

    # Get a path to a temp file
    logfile = Tempfile.new('gitlab_hook_exec')
    logfile.close

    success = system("#{command} > #{logfile.path} 2>&1")
    output_from_command = File.readlines(logfile.path)
    if success
      logger.debug {"GitLabHook: Command output: #{output_from_command.inspect}"}
    else
      logger.error {"GitLabHook: Command '#{command}' didn't exit properly. Full output: #{output_from_command.inspect}"}
    end

    return success
  ensure
    logfile.unlink
  end


  def git_command(prefix, command, repository)
    "#{prefix} " + GIT_BIN + " --git-dir='#{repository.url}' #{command}"
  end


  def clone_repository(prefix, remote_url, local_url)
    "#{prefix} " + GIT_BIN + " clone --mirror #{remote_url} #{local_url}"
  end


  # Fetches updates from the remote repository
  def update_repository(repository)
    Setting.plugin_redmine_gitlab_hook['prune'] == 'yes' ? prune = ' -p' : prune = ''
    prefix = Setting.plugin_redmine_gitlab_hook['git_command_prefix'].to_s

    if Setting.plugin_redmine_gitlab_hook['all_branches'] == 'yes'
      command = git_command(prefix, "fetch --all#{prune}", repository)
      exec(command)
    else
      command = git_command(prefix, "fetch#{prune} origin", repository)
      if exec(command)
        command = git_command(prefix, "fetch#{prune} origin '+refs/heads/*:refs/heads/*'", repository)
        exec(command)
      end
    end
  end


  def get_repository_name
    return params[:project][:name] && params[:project][:name].downcase
  end


  def get_repository_namespace
    return params[:project][:namespace] && params[:project][:namespace].downcase
  end


  # Gets the repository identifier from the querystring parameters and if that's not supplied, assume
  # the GitLab project identifier is the same as the repository identifier.
  def get_repository_identifier
    repo_namespace = get_repository_namespace
    repo_name = get_repository_name || get_project_identifier
    identifier = repo_namespace.present? ? "#{repo_namespace}_#{repo_name}" : repo_name
    return identifier
  end

  # Gets the project identifier from the querystring parameters and if that's not supplied, assume
  # the GitLab repository identifier is the same as the project identifier.
  def get_project_identifier
    identifier = params[:project_id] || params[:project][:name]
    raise ActiveRecord::RecordNotFound, 'Project identifier not specified' if identifier.nil?
    return identifier
  end


  # Finds the Redmine project in the database based on the given project identifier
  def find_project
    identifier = get_project_identifier
    project = Project.find_by_identifier(identifier.downcase)
    raise ActiveRecord::RecordNotFound, "No project found with identifier '#{identifier}'" if project.nil?
    return project
  end


  # Returns the Redmine Repository object we are trying to update
  def find_repository
    project = find_project
    repository_id = get_repository_identifier
    repository = project.repositories.find_by_identifier_param(repository_id)

    if repository.nil?
      if Setting.plugin_redmine_gitlab_hook['auto_create'] == 'yes'
        repository = create_repository(project)
      else
        raise TypeError, "Project '#{project.to_s}' ('#{project.identifier}') has no repository or repository not found with identifier '#{repository_id}'"
      end
    else
      unless repository.is_a?(Repository::Git)
        raise TypeError, "'#{repository_id}' is not a Git repository"
      end
    end

    return repository
  end


  def create_repository(project)
    logger.debug('Trying to create repository...')
    setting = Setting.plugin_redmine_gitlab_hook
    raise TypeError, 'Local repository path is not set' unless setting['local_repositories_path'].to_s.present?

    identifier = get_repository_identifier
    remote_url = params[:project][:git_http_url]

    user_name = setting['git_user_name']
    password = setting['git_user_password']
    if user_name && password
      encoded_user_name = URI.encode_www_form_component(user_name)
      encoded_password = URI.encode_www_form_component(password)
      uri = URI.parse(remote_url)
      uri.userinfo = "#{encoded_user_name}:#{encoded_password}"
      remote_url = uri.to_s
    end

    web_url = params[:project][:web_url]
    prefix = setting['git_command_prefix'].to_s

    raise TypeError, 'Remote repository URL is null' unless remote_url.present?

    local_root_path = setting['local_repositories_path']
    repo_namespace = get_repository_namespace
    repo_name = get_repository_name
    local_url = File.join(local_root_path, repo_namespace, repo_name)
    git_file = File.join(local_url, 'HEAD')

    unless File.exists?(git_file)
      FileUtils.mkdir_p(local_url)
      command = clone_repository(prefix, remote_url, local_url)
      unless exec(command)
        raise RuntimeError, "Can't clone URL #{remote_url},command: #{command}"
      end
    end
    repository = Repository::Git.new
    repository.identifier = identifier
    repository.url = local_url
    repository.is_default = true
    repository.project = project

    # 加入redmine_remote_revision_url的自动配置
    repository.merge_extra_info :extra_remote_revision_url => (web_url + '/commit/:revision')
    repository.merge_extra_info :extra_remote_revision_text => URI.parse(web_url).host

    repository.save
    repository
  end

end
