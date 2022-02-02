# trolled lol
require 'sinatra'
require 'slim'
require 'SQLite3'

require_relative 'helper'

get "/" do
    db = connect_to_db("db/reviewsplus.db")
    slim(:index, locals:{})
end


