#!/usr/bin/ruby
# coding: utf-8

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/json'
require 'sinatra/reloader' if development?
require 'sinatra/assetpack'
require 'haml'
require 'tilt/haml'
require_relative '../models/user'
require_relative '../models/project'
require_relative '../models/participation'
require_relative '../models/schedule'
require_relative './haml/filters/kramdown'

set :method_override, true
set :haml, :escape_html => true
set :root, "#{File.dirname(__FILE__)}/../"

assets do
  serve '/js', from: 'assets/scripts'
  serve '/css', from: 'assets/stylesheets'

  js :main, 'js/main.js', [
    'js/jquery-2.1.1.js'
  ]
  css :main, 'css/main.css', [
    'css/html5-doctor-reset-stylesheet.css'
  ]
  js_compression :closure
  css_compression :sass
end

get '/' do
  redirect '/projects'
end

get '/projects' do
  haml :index, locals: {
    projects: Project.all
  }
end

get '/projects/:id' do |id|
  halt 404 unless Project.exists?(id)
  haml :project, locals: {
    project: Project.find(id)
  }
end

get '/api/projects/:id.json' do |id|
  halt 404 unless Project.exists?(id)
  json Project.find(id).to_json
end

post '/api/projects' do |id|
  project_data = {
    name: params[:name],
    summary: params[:summary]
  }
  json Project.update(project_data).to_json
end

put '/api/projects/:id' do |id|
  halt 404 unless Project.exists?(id)
  project_data = {
    name: params[:name],
    summary: params[:summary]
  }
  json Project.update(id, project_data).to_json
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
    project_id: project_id
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
  json Schedule.update(id, schedule_data).to_json
end

