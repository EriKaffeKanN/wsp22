require 'sinatra'
require 'slim'
require 'SQLite3'
require 'BCrypt'

require_relative 'model'

enable :sessions

include Model
include SlimHelpers

# Checks if the user is logged in before every route where any form of permission is required, including creation of a review, sub-review, tag or category. It also checks if any fields are empty
#
# @see Model#validate_empty_fields
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

# Displays an error message
#
get "/error" do
    "Error: #{session[:error]}" + '<a href="/">Return to homepage</a>'
end

# Clears the error message
#
after "/error" do
    session[:error] = nil
end

# Logs out the user by updating the session
#
post "/users/logout" do
    session[:user_id] = nil
    redirect("/")
end

# Authenticates login attempts and logs in the user if successfull. Locks the user out if more than 5 unsuccessful attempts are made in 5 minutes.
#
# @param [String] login The username or email of a user
# @param [String] password The attempted password
#
# @see Model#authenticate_user
post "/login" do
    if session[:login_attempts] == nil
        session[:login_attempts] = 0
    end
    if session[:last_login_attempt] == nil
        session[:last_login_attempt] = Time.now.to_i
    end
    session[:login_attempts] = 0 if Time.new.to_i - session[:last_login_attempt] > 300 # Reset counter if 5 minutes have passed
    session[:last_login_attempt] = Time.new.to_i

    if session[:login_attempts] > 5
        session[:error] = "Too many login attempts. Try again later."
        redirect("/error")
    end

    loginError = authenticate_user(params[:login], params[:password])
    if loginError == nil
        session[:user_id] = login_user(params[:login])
        redirect("/")
    else
        session[:login_attempts] += 1
        session[:login_error] = loginError
        redirect("/users/login")
    end
end

# Displays the login page
#
get "/users/login" do
    slim(:"users/login", locals:{loginError:session[:loginError]})
end

# Clears the error message shown by invalid login
#
after "/users/login" do
    session[:loginError] = nil
end

# Registers a user if validation is successful
#
# @param [String] username The username
# @param [String] email The email adress
# @param [String] password The password
# @param [String] confirm The repeated password
#
# @see Model#validate_user_registration
post "/users" do
    registrationError = validate_user_registration(params[:username], params[:email], params[:password], params[:confirm])
    if registrationError == nil
        session[:user_id] = register_user(params[:username], params[:email], params[:password])
        redirect("/")
    else
        session[:registrationError] = registrationError
        redirect("/users/new")
    end
end

# Clears the error message shown by invalid registration
#
after "/users/new" do
    session[:registrationError] = nil
end

# Displays the user registration form
#
get "/users/new" do
    slim(:"users/new", locals:{registrationError:session[:registrationError]})
end

# Deletes a review if the current user is the owner of the review, or a moderator of the category in which the review is posted, or an admin
#
# @param [Integer] :review_id The ID of the review
#
# @see Model#get_review
# @see Model#authorize_user_review
# @see Model#delete_review
post "/reviews/:review_id/delete" do
    # Authorize
    review = get_review(params[:review_id])
    ownerId = review["author_id"]
    categoryId = review["category_id"]
    if !authorize_user_review(ownerId, categoryId, session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    delete_review(params[:review_id])
    redirect("/categories/#{review["category_id"]}")
end

# Creates a review if the rating is between 1 and 5
#
# @param [String] review_title The title of the review
# @param [String] review_body The title of the review
# @param [Integer] review_rating The rating of the review
# @param [Integer] category_id The category of the review
#
# @see Model#validate_review_rating
# @see Model#create_new_review
post "/reviews" do
    title = params[:review_title]
    body = params[:review_body]
    rating = params[:review_rating]
    category = params[:category_id]
    user = session[:user_id]
    if !validate_review_rating(rating)
        session[:error] = "Invalid rating"
        redirect("/error")
    end
    create_new_review(title, body, rating, user, category)
    redirect("/categories/#{params[:category_id]}")
end

# Displays the form for creating a new review
#
get "/reviews/new" do
    slim(:"reviews/new", locals:{category_id:session[:current_category]})
end

# Removes all tags from a review
#
# @param [Integer] :review_id The ID of the review
#
# @see Model#get_review
# @see Model#authorize_user_review
# @see Model#get_tag_ids
# @see Model#remove_tag
post "/reviews/:review_id/delete_tags" do
    review = get_review(params[:review_id])
    if !authorize_user_review(review["author_id"], review["category_id"], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    tags = get_tag_ids(params[:review_id])
    for id in tags
        remove_tag(id, params[:review_id])
    end
    redirect("/reviews/#{params[:review_id]}")
end

# Adds a tag to a review if the tag exists within the category of the review
#
# @param [Integer] :review_id The ID of the review
# @param [Integer] :tag_id The ID of the tag
#
# @see Model#get_review
# @see Model#validate_tag
# @see Model#authorize_user_review
# @see Model#add_tag
post "/reviews/:review_id/update_tags" do
    review = get_review(params[:review_id])
    if !validate_tag(params[:tag_id], review["category_id"])
        session[:error] = "That tag does not belong to that category"
        redirect("/error")
    end
    if !authorize_user_review(review["author_id"], review["category_id"], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    add_tag(params[:tag_id], params[:review_id])
    redirect("/reviews/#{params[:review_id]}")
end

# Displays the form for adding a tag to a review
#
# @param [Integer] :review_id The ID of the review
#
# @see Model#get_review
# @see Model#get_tags_in_category
get "/reviews/:review_id/edit_tags" do
    review = get_review(params[:review_id])
    tags = get_tags_in_category(review["category_id"])
    slim(:"reviews/edit_tags", locals:{review_id:params[:review_id], tags:tags})
end

# Updates a review if the rating is between 1 and 5 and the user is either the owner of the review, or a moderator of the category in which the review is posted, or an admin
#
# @param [Integer] :review_id The ID of the review
# @param [String] title The new title of the review
# @param [String] body The new body of the review
# @param [Integer] rating The new rating of the review
#
# @see Model#validate_review_rating
# @see Model#get_review
# @see Model#authorize_user_review
# @see Model#update_review
post "/reviews/:review_id/update" do
    title = params[:title]
    body = params[:body]
    rating = params[:rating]
    if !validate_review_rating(rating)
        session[:error] = "Invalid rating"
        redirect("/error")
    end

    review = get_review(params[:review_id])
    if !authorize_user_review(review["author_id"], review["category_id"], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    update_review(title, body, rating, params[:review_id])
    redirect("/reviews/#{params[:review_id]}")
end

# Displays the form for editing a review
#
# @param [Integer] :review_id The ID of the review
#
# @see Model#get_review
get "/reviews/:review_id/edit" do
    review = get_review(params[:review_id])
    slim(:"reviews/edit", locals:{review:review})
end

# Displays a review, also displays a message if the user is the owner of the review, or a moderator of the category in which the review is posted, or an admin
#
# @param [Integer] :review_id The ID of the review
#
# @see Model#get_review
# @see Model#authorize_user_review
# @see Model#get_sub_reviews
get "/reviews/:review_id" do
    review = get_review(params[:review_id])
    categoryId = review["category_id"]
    authorized = authorize_user_review(review["author_id"], categoryId, session[:user_id])
    subReviews = get_sub_reviews(params[:review_id])
    session[:current_review] = params[:review_id].to_i
    slim(:"reviews/show", locals:{review:review, authorized:authorized, sub_reviews:subReviews, user_id:session[:user_id]})
end

# Deletes a sub-review if the current user is the owner of the sub-review, or a moderator of the category in which the mother-review is posted, or an admin
#
# @param [Integer] :id The ID of the sub-review
#
# @see Model#get_sub_review
# @see Model#authorize_user_sub_review
post "/sub_reviews/:id/delete" do
    subReview = get_sub_review(params[:id])
    if !authorize_user_sub_review(subReview["author_id"], subReview["review_id"], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    redirect("/reviews/#{subReview["review_id"]}")
end

# Updates a sub-review if the rating is between 1 and 5 and the user is either the owner of the sub-review, or a moderator of the category in which the mother-review is posted, or an admin
#
# @param [Integer] :id The ID of the sub-review
# @param [String] title The new title of the sub-review
# @param [String] body The new body of the sub-review
# @param [Integer] rating The new rating of the sub-review
#
# @see Model#validate_review_rating
# @see Model#get_sub_review
# @see Model#authorize_user_sub_review
# @see Model#update_sub_review
post "/sub_reviews/:id/update" do
    title = params[:title]
    body = params[:body]
    rating = params[:rating]
    if !validate_review_rating(rating)
        session[:error] = "Invalid rating"
        redirect("/error")
    end

    subReview = get_sub_review(params[:id])
    if !authorize_user_sub_review(subReview["author_id"], subReview["review_id"], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    update_sub_review(title, body, rating, params[:id])
    redirect("/reviews/#{subReview["review_id"]}")
end

# Displays the form for editing a sub-review
#
# @param [Integer] :id The ID of the sub-review
#
# @see Model#get_sub_review
get "/sub_reviews/:id/edit" do
    subReview = get_sub_review(params[:id])
    slim(:"sub_reviews/edit", locals:{sub_review:subReview})
end

# Creates a sub-review if the rating is between 1 and 5
#
# @param [String] title The title of the review
# @param [String] body The title of the review
# @param [Integer] rating The rating of the review
# @param [Integer] review The ID of the mother-review
#
# @see Model#validate_review_rating
# @see Model#create_new_sub_review
post "/sub_reviews" do
    title = params[:title]
    body = params[:body]
    rating = params[:rating]
    user = session[:user_id]
    review = params[:review]
    if !validate_review_rating(rating)
        session[:error] = "Invalid rating"
        redirect("/error")
    end

    create_new_sub_review(title, body, rating, user, review)
    redirect("/reviews/#{review}")
end

# Displays the form for creating a new sub-review
#
get "/sub_reviews/new" do
    slim(:"sub_reviews/new", locals:{review_id:session[:current_review]})
end

# Displays a sub-review, also displays a message if the user is the owner of the sub-review, a moderator of the category in which the mother-review is posted, or an admin
#
# @param [Integer] :id the ID of the sub-review
#
# @see Model#get_sub_review
# @see Model#authorize_user_sub_review
get "/sub_reviews/:id" do
    subReview = get_sub_review(params[:id])
    reviewId = subReview["review_id"]
    authorized = authorize_user_sub_review(subReview["author_id"], reviewId, session[:user_id])
    slim(:"sub_reviews/show", locals:{sub_review:subReview, authorized:authorized})
end

# Creates a new category, requires no permission aside from being logged in
#
# @param [String] cat_name The name of the category
#
# @see Model#create_new_category
post "/categories" do
    name = params[:cat_name]
    create_new_category(name, session[:user_id])
    redirect("/categories/")
end

# Displays the form for creating a new category
#
get "/categories/new" do
    slim(:"categories/new")
end

# Updates a category if the user is a moderator of the category or an admin
#
# @param [Integer] :id The ID of the category
# @param [Integer] name The name of the category
#
# @see Model#authorize_user_category
# @see Model#update_category
post "/categories/:id/update" do
    if !authorize_user_category(params[:id], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    update_category(params[:id], params[:name])
    redirect("/categories/#{params[:id]}")
end

# Displays the form for editing a category
#
# @param [Integer] :id The ID of the category
#
# @see Model#get_category
get "/categories/:id/edit" do
    category = get_category(params[:id])
    slim(:"categories/edit", locals:{category:category})
end

# Deletes a category if the user is a moderator of the category or an admin
#
# @param [Integer] :id The ID of the category
#
# @see Model#authorize_user_category
# @see Model#delete_category
post "/categories/:id/delete" do
    if !authorize_user_category(params[:id], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    delete_category(params[:id])
    redirect("/categories/")
end

# Displays all the reviews within a category, also displays a message if the user is a moderator of the category
#
# @param [Integer] :id The ID of the category
#
# @see Model#get_category
# @see Model#get_reviews
get "/categories/:id" do
    category = get_category(params[:id])
    reviews = get_reviews(params[:id])
    mod = user_is_moderator(params[:id], session[:user_id])
    session[:current_category] = params[:id].to_i
    slim(:"categories/show", locals:{category:category, reviews:reviews, mod:mod, user_id:session[:user_id]})
end

# Displays all categories
#
# @see SlimHelpers#get_categories
get "/categories/" do
    categories = get_categories
    slim(:"categories/index", locals:{data:categories})
end

# Creates a tag if the current user is a moderator of the category in which the tag is created, or an admin
#
# @param [Integer] category_id The ID of the category in which the tag is created
# @param [Integer] name The name of the tag
#
# @see Model#authorize_user_category
# @see Model#create_new_tag
post "/tags" do
    if !authorize_user_category(params[:category_id], session[:user_id])
        session[:error] = "You do not have permission to perform this action"
        redirect("/error")
    end
    create_new_tag(params[:name], params[:category_id])
    redirect("/categories/#{params[:category_id]}")
end

# Displays the form for creating a new tag
#
get "/tags/new" do
    slim(:"tags/new", locals:{category_id:session[:current_category], user_id:session[:user_id]})
end

# Displays the landing page
#
get "/" do
    slim(:index)
end