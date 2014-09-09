
require 'sinatra/activerecord'

class Patch < ActiveRecord::Base
  belongs_to :histories, polymorphic: true
end

