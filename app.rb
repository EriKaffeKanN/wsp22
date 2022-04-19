# trolled lol
require 'sinatra'
require 'slim'
require 'SQLite3'
require 'BCrypt'

require_relative 'model'

enable :sessions

# --- Constants ---
def dbPath
    "db/reviewsplus.db"
end

# --- Misc ---
before do
    if request.path_info != "/users/new"
        if (request.path_info.include?("/new") || request.path_info.include?("/edit")) && session[:user_id] == nil
            session[:error] = "You need to log in to perform this action"
            redirect("/error")
        end
    end
end

get "/error" do
    "Error: #{session[:error]}" + '<a href="/">Return to homepage</a>'
end

# --- Standard routes ---

post "/users/logout" do
    session[:user_id] = nil
    redirect("/")
end

post "/login" do
    # TODO: VALIDATE
    if authenticate_user(params[:login], params[:password])
        login_user(params[:login])
        redirect("/")
    else
        redirect("/users/login")
    end
end

get "/users/login" do
    slim(:"users/login", locals:{loginError:session[:loginError]})
end

post "/users" do
    if validate_user_registration(params[:username], params[:email], params[:password], params[:confirm])
        register_user(params[:username], params[:email], params[:password])
        redirect("/")
    else
        redirect("/users/new")
    end
end

after "/users" do
    session[:loginError] = nil
end

get "/users/new" do
    slim(:"users/new", locals:{loginError:session[:loginError]})
end

get "/users/" do
    slim(:"users/list", locals:{})
end

post "/categories/:category_id/:review_id/delete" do
    # Authorize
    review = get_review(params[:review_id])
    ownerId = review["author_id"]
    categoryId = review["category_id"]
    if !authorize_user(ownerId, categoryId)
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    delete_review(params[:review_id])
    redirect("/categories/#{params[:category_id]}")
end

post "/categories/:id" do
    title = params[:review_title]
    body = params[:review_body]
    rating = params[:review_rating]
    create_new_review(title, body, rating, session[:user_id], params[:id])
    redirect("/categories/#{params[:id]}")
end

get "/categories/:id/new" do
    category = get_category(params[:id])
    slim(:"reviews/new", locals:{category:category})
end

get "/categories/:category_id/:review_id" do
    review = get_review(params[:review_id])
    slim(:"reviews/display", locals:{review:review})
end

post "/categories/new" do
    name = params[:cat_name]
    create_new_category(name)
    redirect("/categories")
end

get "/categories/new" do
    slim(:"categories/new")
end

get "/categories/:id/" do
    category = get_category(params[:id])
    reviews = get_reviews(params[:id])
    mod = userIsModerator(params[:id])
    slim(:"reviews/list", locals:{category:category, reviews:reviews, mod:mod})
end

get "/categories/" do
    categories = get_categories
    slim(:"categories/list", locals:{data:categories})
end

get "/" do
    slim(:index)
end