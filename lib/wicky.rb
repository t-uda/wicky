#!/usr/bin/ruby
# coding: utf-8

require 'sinatra/base'
require 'sinatra/activerecord'
require 'sinatra/json'
require 'sinatra/reloader'
require 'sinatra/assetpack'
require 'sinatra/param'
require 'haml'
require 'tilt/haml'
require_relative '../models/user'
require_relative '../models/project'
require_relative '../models/participation'
require_relative '../models/schedule'
require_relative '../models/patch'
require_relative './haml/filters/kramdown'
require_relative './difftool'

module Wicky
  class App < Sinatra::Base

    helpers Sinatra::Param
    register Sinatra::AssetPack

    configure :development do
      register Sinatra::Reloader
    end

    configure do
      enable :method_override
      set :haml, :escape_html => true
      set :root, "#{File.dirname(__FILE__)}/../"
    end

    assets do
      serve '/js', from: 'assets/scripts'
      serve '/css', from: 'assets/stylesheets'

      js :main, '/js/main.js', [
        '/js/lib/jquery-2.1.1.js',
        '/js/wicky.js',
        '/js/wicky/ui.js',
        '/js/wicky/projects.js'
      ]
      css :main, '/css/main.css', [
        '/css/html5-doctor-reset-stylesheet.css',
        '/css/bootstrap.css',
        '/css/bootstrap-theme.css'
      ]
      js_compression :closure
      css_compression :sass
    end

    helpers do
      def bind(id, api, &block)
        capture_haml do
          haml_tag 'div.ui-bind', { 'data-bind-id' => id, 'data-bind-update-api' => api }, &block
        end
      end

      def haml_page(id, locals)
        haml :"pages/#{id.to_s}", { layout: true }, locals
      end

      def haml_partial(id, locals)
        haml :"partial_templates/#{id.to_s}", { layout: false }, locals
      end

      def preserve_newline(input = nil, &block)
        return preserve_newline(capture_haml(&block)) if block
        s = input.to_s
        s.gsub!(/\n/, '&#x000A;')
        s.delete!("\r")
        s
      end

      def merge_schedule_description!(schedule, your_original, your_description)
        my_description = schedule.description
        new_description = Wicky::DiffTool::merge3 my_description, your_original, your_description do |rej|
          return { is_conflicted: true, description: rej }
        end
        diff = Wicky::DiffTool::diff my_description, new_description
        schedule.patches << Patch.create(content: diff)
        schedule.description = new_description
        schedule.save!
        return { is_conflicted: false, description: new_description }
      end
    end

    get '/' do
      haml_page :index, {
        projects: Project.all,
        schedules: Schedule.all
      }
    end

    post '/projects/!add' do
      project_data = {
        name: params[:name]
      }
      project = Project.create(project_data)
      redirect "/projects/#{project.id}/"
    end

    get '/projects/:id/' do |id|
      halt 404 unless Project.exists?(id)
      haml_page "projects/:id", {
        project: Project.find(id),
        is_conflicted: false
      }
    end

    get '/projects/:id/schedules/!list' do |id|
      halt 404 unless Project.exists?(id)
      haml_partial :schedules, { schedules: Project.find(id).schedules }
    end

    get '/projects/:id/users/!list' do |id|
      halt 404 unless Project.exists?(id)
      haml_partial :users, { users: Project.find(id).users }
    end

    get '/projects/:id/!show' do |id|
      param :is_conflicted, Boolean, required: true
      param :summary, String
      halt 404 unless Project.exists?(id)
      locals = {
        project: Project.find(id),
        is_conflicted: params[:is_conflicted]
      }
      locals[:conflicted_summary] = params[:summary] if params[:is_conflicted]
      haml_partial :a_project, locals
    end

    get '/schedules/:id/!show' do |id|
      param :is_conflicted, Boolean, required: true
      param :description, String
      halt 404 unless Schedule.exists?(id)
      locals = {
        schedule: Schedule.find(id),
        is_conflicted: params[:is_conflicted]
      }
      locals[:conflicted_description] = params[:description] if params[:is_conflicted]
      haml_partial :a_schedule, locals
    end

    get '/api/projects/:id.json' do |id|
      halt 404 unless Project.exists?(id)
      json Project.find(id).to_json
    end

    post '/api/projects' do
      project_data = {
        name: params[:name],
        summary: params[:summary]
      }
      json Project.create(project_data).to_json
    end

    put '/api/projects/:id' do |id|
      halt 404 unless Project.exists?(id)
      project_data = {
        name: params[:name],
        summary: params[:summary]
      }
      json Project.update(id, project_data).to_json
    end

    put '/api/projects/:id/summary' do |id|
      halt 404 unless Project.exists?(id)
      project = Project.find id
      your_original = params[:original]
      your_summary = params[:summary]
      my_summary = project.summary
      new_summary = Wicky::DiffTool::merge3 my_summary, your_original, your_summary do |rej|
        return json(is_conflicted: true, summary: rej)
      end
      diff = Wicky::DiffTool::diff my_summary, new_summary
      project.patches << Patch.create(content: diff)
      project.summary = new_summary
      project.save!
      return json(is_conflicted: false, summary: project.summary)
    end

    get '/api/users.json' do
      json User.all
    end

    get '/api/users/:id.json' do |id|
      halt 404 unless User.exists?(id)
      json User.find(id).to_json
    end

    post '/api/users' do
      user_data = {
        name: params[:name],
        email: params[:email]
      }
      halt 409 if User.exists?(user_data)
      json User.create(user_data).to_json
    end

    put '/api/users/:id' do |id|
      halt 404 unless User.exists?(id)
      user_data = {
        name: params[:name],
        email: params[:email]
      }
      json User.update(id, user_data).to_json
    end

    post '/api/participations' do
      user_data = {
        name: params[:name],
        email: params[:email]
      }
      user = User.find_or_create_by(user_data)
      user_id = user.id
      project_id = params[:project_id]
      halt 404 unless Project.exists?(project_id)
      project = Project.find(project_id)
      halt 409 if Participation.exists?(user_id: user_id, project_id: project_id)
      project.users.push user
      project.save
      json({
        project_id: project_id,
        user_id: user_id,
      })
    end

    post '/api/schedules' do
      project_id = params[:project_id]
      halt 404 unless Project.exists?(project_id)
      schedule_data = {
        name: params[:name],
        place: params[:place],
        start: time_for(params[:start]),
        end: time_for(params[:end]),
        project_id: project_id,
        description: ''
      }
      json Schedule.create(schedule_data).to_json
    end

    put '/api/schedules/:id' do |id|
      project_id = params[:project_id]
      halt 404 unless Project.exists?(project_id)
      halt 404 unless Schedule.exists?(id)
      schedule_data = {
        name: params[:name],
        place: params[:place],
        start: time_for(params[:start]),
        end: time_for(params[:end]),
        project_id: project_id
      }
      schedule = Schedule.update(id, schedule_data)
      result = merge_schedule_description! schedule, params[:original], params[:description]
      result[:schedule] = schedule
      return json(result)
    end

    put '/api/schedules/:id/description' do |id|
      halt 404 unless Schedule.exists?(id)
      schedule = Schedule.find id
      result = merge_schedule_description! schedule, params[:original], params[:description]
      return json(result)
    end

    get '/api/kramdown' do
      text = params[:md]
      Kramdown::Document.new(text, {}).to_html
    end

    run! if app_file == $0

  end # class App
end # module Wicky

