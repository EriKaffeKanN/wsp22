# trolled lol
require 'sinatra'
require 'slim'
require 'SQLite3'
require 'BCrypt'

require_relative 'model'

enable :sessions

post "/users" do
    
end

get "/users/new" do
    slim(:"users/new", locals:{})
end

get "/users/" do
    slim(:"users/list", locals:{})
end

post "/categories/:category_id/:review_id/delete" do
    db = connect_to_db("db/reviewsplus.db")
    db.execute("DELETE FROM review WHERE id = ?", params["review_id"])
    redirect("/categories/#{params["category_id"]}")
end

post "/categories/:id/new" do
    db = connect_to_db("db/reviewsplus.db")
    title = params["review_title"]
    body = params["review_body"]
    rating = params["review_rating"]
    db.execute("INSERT INTO review (title, body, rating, author_id, category_id) VALUES (?, ?, ?, ?, ?)", title, body, rating, 0, params["id"])
    redirect("/categories/#{params["id"]}")
end

get "/categories/:id/new" do
    db = connect_to_db("db/reviewsplus.db")
    category = db.execute("SELECT * FROM category WHERE id = ?", params["id"])
    slim(:"reviews/new", locals:{category:category[0]})
end

get "/categories/:category_id/:review_id" do
    db = connect_to_db("db/reviewsplus.db")
    review = db.execute("SELECT * FROM review WHERE id = ?", params["review_id"])
    slim(:"reviews/display", locals:{review:review[0]})
end

post "/categories/new" do
    db = connect_to_db("db/reviewsplus.db")
    name = params["cat_name"]
    db.execute("INSERT INTO category (name) VALUES (?)", name)
    redirect("/categories")
end

get "/categories/new" do
    slim(:"categories/new")
end

get "/categories/:id" do
    db = connect_to_db("db/reviewsplus.db")
    cat_id = params[:id]
    category = db.execute("SELECT * FROM category WHERE id = ?", cat_id)
    reviews = db.execute("SELECT * FROM review WHERE category_id = ?", cat_id)
    slim(:"reviews/list", locals:{category:category[0], reviews:reviews})
end

get "/categories" do
    db = connect_to_db("db/reviewsplus.db")
    categories = db.execute("SELECT * FROM category")
    p categories
    slim(:"categories/list", locals:{data:categories})
end

get "/" do
    db = connect_to_db("db/reviewsplus.db")
    slim(:index, locals:{})
end