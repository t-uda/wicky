#!/usr/bin/ruby
# coding: utf-8

require 'sinatra'
require 'sinatra/activerecord'
require 'haml'
require 'tilt/haml'
require_relative '../models/user'
require_relative '../models/project'
require_relative '../models/participation'
require_relative '../models/schedule'
require_relative './haml/filters/kramdown'

set :haml, :escape_html => true
set :views, "#{File.dirname(__FILE__)}/../views"

get '/' do
  haml :index, locals: {
    projects: Project.all
  }
end

get '/project/:id' do |id|
  haml :project, locals: {
    project: Project.find(id)
  }
end

