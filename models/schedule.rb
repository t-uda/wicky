
require 'sinatra/activerecord'

class Schedule < ActiveRecord::Base
  belongs_to :project
  has_many :patches, as: :histories
end

