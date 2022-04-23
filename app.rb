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
        if (request.path_info.include?("/new") || request.path_info.include?("/edit") || request.path_info.include?("/delete")) && session[:user_id] == nil
            session[:error] = "You need to log in to perform this action"
            redirect("/error")
        end
    end
    if !validate_empty_fields(params)
        session[:error] = "Empty fields are not allowed"
        redirect("/error")
    end
end

get "/error" do
    "Error: #{session[:error]}" + '<a href="/">Return to homepage</a>'
end

# --- Standard routes ---

# Users

post "/users/logout" do
    session[:user_id] = nil
    redirect("/")
end

post "/login" do
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

# Reviews

post "/reviews/:review_id/delete" do
    # Authorize
    review = get_review(params[:review_id])
    ownerId = review["author_id"]
    categoryId = review["category_id"]
    if !authorize_user_review(ownerId, categoryId)
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    delete_review(params[:review_id])
    redirect("/categories/#{review["category_id"]}")
end

post "/reviews" do
    title = params[:review_title]
    body = params[:review_body]
    rating = params[:review_rating]
    category = params[:category_id]
    user = session[:user_id]
    create_new_review(title, body, rating, user, category)
    redirect("/categories/#{params[:category_id]}")
end

get "/reviews/new" do
    slim(:"reviews/new", locals:{category_id:session[:current_category]})
end

post "/reviews/:review_id/update_tags" do
    review = get_review(params[:review_id])
    if !validate_tag(params[:tag_id], review["category_id"])
        session[:error] = "That tag does not belong to that category"
        redirect("/error")
    end
    if !authorize_user_review(review["author_id"], review["category_id"])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    add_tag(params[:tag_id], params[:review_id])
    redirect("/reviews/#{params[:review_id]}")
end

get "/reviews/:review_id/edit_tags" do
    review = get_review(params[:review_id])
    tags = get_tags_in_category(review["category_id"])
    slim(:"reviews/edit_tags", locals:{review_id:params[:review_id], tags:tags})
end

post "/reviews/:review_id/update" do
    title = params[:title]
    body = params[:body]
    rating = params[:rating]

    review = get_review(params[:review_id])
    if !authorize_user_review(review["author_id"], review["category_id"])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    update_review(title, body, rating, params[:review_id])
    redirect("/reviews/#{params[:review_id]}")
end

get "/reviews/:review_id/edit" do
    slim(:"reviews/edit", locals:{review_id:params[:review_id]})
end

get "/reviews/:review_id" do
    review = get_review(params[:review_id])
    categoryId = review["category_id"]
    authorized = authorize_user_review(review["author_id"], categoryId)
    subReviews = get_sub_reviews(params[:review_id])
    session[:current_review] = params[:review_id].to_i
    slim(:"reviews/display", locals:{review:review, authorized:authorized, sub_reviews:subReviews})
end

# Sub-reviews

post "/sub_reviews/:id/delete" do
    subReview = get_sub_review(params[:id])
    if !authorize_user_sub_review(subReview["author_id"], subReview["review_id"])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    redirect("/reviews/#{subReview["review_id"]}")
end

post "/sub_reviews/:id/update" do
    title = params[:title]
    body = params[:body]
    rating = params[:rating]

    subReview = get_sub_review(params[:id])
    if !authorize_user_sub_review(subReview["author_id"], subReview["review_id"])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    update_sub_review(title, body, rating, params[:id])
    redirect("/reviews/#{subReview["review_id"]}")
end

get "/sub_reviews/:id/edit" do
    slim(:"sub_reviews/edit", locals:{sub_review_id:params[:id]})
end

post "/sub_reviews" do
    title = params[:title]
    body = params[:body]
    rating = params[:rating]
    user = session[:user_id]
    review = params[:review]

    create_new_sub_review(title, body, rating, user, review)
    redirect("/reviews/#{review}")
end

get "/sub_reviews/new" do
    slim(:"sub_reviews/new", locals:{review_id:session[:current_review]})
end

get "/sub_reviews/:id" do
    subReview = get_sub_review(params[:id])
    reviewId = subReview["review_id"]
    authorized = authorize_user_sub_review(subReview["author_id"], reviewId)
    slim(:"sub_reviews/display", locals:{sub_review:subReview, authorized:authorized})
end

# Categories

post "/categories" do
    name = params[:cat_name]
    create_new_category(name)
    redirect("/categories/")
end

get "/categories/new" do
    slim(:"categories/new")
end

post "/categories/:id/update" do
    if !authorize_user_category(params[:id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    update_category(params[:id], params[:name])
    redirect("/categories/#{params[:id]}")
end

get "/categories/:id/edit" do
    category = get_category(params[:id])
    slim(:"categories/edit", locals:{category:category})
end

post "/categories/:id/delete" do
    if !authorize_user_category(params[:id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    delete_category(params[:id])
    redirect("/categories/")
end

get "/categories/:id" do
    category = get_category(params[:id])
    reviews = get_reviews(params[:id])
    mod = user_is_moderator(params[:id])
    session[:current_category] = params[:id].to_i
    slim(:"reviews/list", locals:{category:category, reviews:reviews, mod:mod})
end

get "/categories/" do
    categories = get_categories
    slim(:"categories/list", locals:{data:categories})
end

post "/tags" do
    if !authorize_user_category(params[:category_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    create_new_tag(params[:name], params[:category_id])
    redirect("/categories/#{params[:category_id]}")
end

get "/tags/new" do
    slim(:"tags/new", locals:{category_id:session[:current_category]})
end

get "/" do
    slim(:index)
end