require 'uri'

# All methods that interact with the database
#
module Model
    
    # The path to the database
    #
    DB_PATH = "db/reviewsplus.db"

    # Connects to a database
    #
    # @param [String] path Path to the database
    #
    # @return [SQLite3::Database] The database
    def connect_to_db(path)
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end

    # Gets a category from the database
    #
    # @param [Integer] categoryId The id of the category
    #
    # @return [Hash] The category
    #   * :id [Integer] The id of the category
    #   * :id [String] The name of the category
    def get_category(categoryId)
        db = connect_to_db(DB_PATH)
        return db.execute("SELECT * FROM category WHERE id = ?", categoryId).first
    end

    # Updates the values of a category
    #
    # @param [Integer] categoryId The id of the category
    # @param [String] newName The new name of the category
    def update_category(categoryId, newName)
        db = connect_to_db(DB_PATH)
        db.execute("UPDATE category SET name = ? WHERE id = ?", newName, categoryId)
    end

    # Deletes a category as well as all reviews, sub-reviews and tags connected to it
    #
    # @param [Integer] categoryId The id of the category
    def delete_category(categoryId)
        db = connect_to_db(DB_PATH)
        db.execute("DELETE FROM category WHERE id = ?", categoryId)
        db.execute("DELETE FROM moderator_category_relation WHERE category_id = ?", categoryId)
        db.execute("DELETE FROM tag WHERE category_id = ?", categoryId)
        reviewIds = get_reviews(categoryId).map{|review| review["id"]}
        for id in reviewIds
            delete_review(id)
        end
    end

    # Updates the values of a sub-review
    #
    # @param [String] title The new title of the sub-review
    # @param [String] body The new body of the sub-review
    # @param [Integer] rating The new rating of the sub-review
    # @param [Integer] subReviewId The id of the sub-review
    def update_sub_review(title, body, rating, subReviewId)
        db = connect_to_db(DB_PATH)
        db.execute("UPDATE sub_review SET title = ?, body = ?, rating = ? WHERE id = ?", title, body, rating, subReviewId)
    end

    # Updates the values of a review
    #
    # @param [String] title The new title of the review
    # @param [String] body The new body of the review
    # @param [Integer] rating The new rating of the review
    # @param [Integer] reviewId The id of the review
    def update_review(title, body, rating, reviewId)
        db = connect_to_db(DB_PATH)
        db.execute("UPDATE review SET title = ?, body = ?, rating = ? WHERE id = ?", title, body, rating, reviewId)
    end

    # Deletes a review along with all sub-reviews and tag-relations connected to it
    #
    # @param [Integer] reviewId The id of the review
    def delete_review(reviewId)
        db = connect_to_db(DB_PATH)
        db.execute("DELETE FROM review WHERE id = ?", reviewId)
        db.execute("DELETE FROM review_tag_relation WHERE review_id = ?", reviewId)
        db.execute("DELETE FROM sub_review WHERE review_id = ?", reviewId)
    end

    # Creates a new category
    #
    # @param [String] name The name of the category
    def create_new_category(name)
        db = connect_to_db(DB_PATH)
        db.execute("INSERT INTO category (name) VALUES (?)", name)
        categoryId = db.execute("SELECT last_insert_rowid()").first["last_insert_rowid()"]
        db.execute("INSERT INTO moderator_category_relation (mod_id, category_id) VALUES (?, ?)", session[:user_id], categoryId)
    end

    # Creates a new tag
    #
    # @param [String] name The name of the tag
    # @param [Integer] categoryId The id of the category that the tag should belong to
    def create_new_tag(name, categoryId)
        db = connect_to_db(DB_PATH)
        db.execute("INSERT INTO tag (name, category_id) VALUES (?, ?)", name, categoryId)
    end

    # Deletes a new tag
    #
    # @param [Integer] tagId The id of the tag that should be deleted
    def delete_tag(tagId)
        db = connect_to_db(DB_PATH)
        db.execute("DELETE FROM tag WHERE id = ?", tagId)
        db.execute("DELETE FROM tag_review_relation WHERE tag_id = ?", tagId)
    end

    # Gets all tag names linked to a review
    #
    # @param [Integer] reviewId The id of the review
    #
    # @return [Array<String>] The names of the tags
    def get_tags(reviewId)
        db = connect_to_db(DB_PATH)
        tags = db.execute("SELECT name FROM review_tag_relation LEFT JOIN tag ON review_tag_relation.tag_id WHERE id = tag_id AND review_id = ?", reviewId)
        tags.map!{|t| t["name"]}
        return tags
    end

    # Gets all tag ids linked to a review
    #
    # @param [Integer] reviewId The id of the review
    #
    # @return [Array<Integer>] The ids of the tags
    def get_tag_ids(reviewId)
        db = connect_to_db(DB_PATH)
        tags = db.execute("SELECT id FROM review_tag_relation LEFT JOIN tag ON review_tag_relation.tag_id WHERE id = tag_id AND review_id = ?", reviewId)
        tags.map!{|t| t["id"]}
        return tags
    end

    # Gets all tags within a category
    #
    # @param [Integer] categoryId The id of the category
    #
    # @return [Array<Hash>] The tags
    def get_tags_in_category(categoryId)
        db = connect_to_db(DB_PATH)
        return db.execute("SELECT * FROM tag WHERE category_id = ?", categoryId)
    end

    # Gets a sub-review from the database
    #
    # @param [Integer] subReviewId The id of the sub-review
    #
    # @return [Hash] The sub-review
    #   * :id [Integer] The id of the sub-review
    #   * :title [String] The title of the sub-review
    #   * :rating [Integer] The rating of the sub-review
    #   * :body [String] The body of the sub-review
    #   * :review_id [Integer] The review id of the sub-review
    #   * :author_id [Integer] The id of the sub-review's owner
    def get_sub_review(subReviewId)
        db = connect_to_db(DB_PATH)
        return db.execute("SELECT * FROM sub_review WHERE id = ?", subReviewId).first
    end

    # Gets a review from the database
    #
    # @param [Integer] reviewId The id of the review
    #
    # @return [Hash] The review
    #   * :id [Integer] The id of the review
    #   * :title [String] The title of the review
    #   * :rating [Integer] The rating of the review
    #   * :body [String] The body of the review
    #   * :category_id [Integer] The category id of the review
    #   * :author_id [Integer] The id of the review's owner
    def get_review(reviewId)
        db = connect_to_db(DB_PATH)
        return db.execute("SELECT * FROM review WHERE id = ?", reviewId).first
    end

    # Creates a new review
    #
    # @param [String] title The title of the review
    # @param [String] body The body of the review
    # @param [Integer] rating The rating of the review
    # @param [Integer] ownerId The id of the review's owner
    # @param [Integer] categoryId The category id of the review
    def create_new_review(title, body, rating, ownerId, categoryId)
        db = connect_to_db(DB_PATH)
        db.execute("INSERT INTO review (title, body, rating, author_id, category_id) VALUES (?, ?, ?, ?, ?)", title, body, rating, ownerId, categoryId)
    end

    # Creates a new sub-review
    #
    # @param [String] title The title of the sub-review
    # @param [String] body The body of the sub-review
    # @param [Integer] rating The rating of the sub-review
    # @param [Integer] ownerId The id of the sub-review's owner
    # @param [Integer] reviewId The review id of the sub-review
    def create_new_sub_review(title, body, rating, ownerId, reviewId)
        db = connect_to_db(DB_PATH)
        db.execute("INSERT INTO sub_review (title, body, rating, author_id, review_id) VALUES (?, ?, ?, ?, ?)", title, body, rating, ownerId, reviewId)
    end

    # Checks if a review's rating is between 1 and 5
    #
    # @param [String] rating The title of the sub-review
    #
    # @return [Boolean] Whether the rating is valid or not
    def validate_review_rating(rating)
        return rating.to_i >= 1 && rating.to_i <= 5
    end

    # Checks if the any of the fields of a form are empty
    #
    # @param [Hash] fields The fields
    # @option fields [String] name
    # @option fields [String] value
    #
    # @return [Boolean] Whether or not the any of the fields are empty
    def validate_empty_fields(fields)
        for f in fields
            value = f[1]
            if value == "" || value == nil
                return false
            end
        end
        return true
    end

    # Validates user registration, makes sure the password is 8 characters or more, makes sure the password contains a number, makes sure the passwords match
    #
    # @param [String] username
    # @param [String] email
    # @param [String] password
    # @param [String] confirm Confirm password
    #
    # @return [Boolean] Whether the registration is valid or not
    def validate_user_registration(username, email, password, confirm)
        db = connect_to_db(DB_PATH)

        nameAldreadyExists = !db.execute("SELECT * FROM user WHERE name = ?", username).empty?
        if nameAldreadyExists
            session[:registrationError] = "The name already exists"
            return false
        end

        # Email
        emailCorrectlyFormatted = URI::MailTo::EMAIL_REGEXP.match?(email)
        emailAlreadyExists = !db.execute("SELECT * FROM user WHERE email = ?", email).empty?
        if !emailCorrectlyFormatted
            session[:registrationError] = "Use a real email adress"
            return false
        elsif emailAlreadyExists
            session[:registrationError] = "That email already exists"
            return false
        end
        # Password
        if password != confirm
            session[:registrationError] = "Passwords did not match each other"
            return false
        elsif password.length < 8
            session[:registrationError] = "Password needs to be 8 characters or more"
            return false
        elsif !string_contains_any?(password, "1234567890")
            session[:registrationError] = "Password needs to contain at least 1 numerical value"
            return false
        end
        return true
    end

    # Checks if a tag exists within a category
    #
    # @param [Integer] tagId The id of the tag
    # @param [Integer] categoryId The id of the category
    #
    # @return [Boolean] Whether the tag is linked to the category
    def validate_tag(tagId, categoryId)
        validTags = get_tags_in_category(categoryId)
        validTagIds = validTags.map{|tag| tag["id"]}
        return validTagIds.include?(tagId.to_i)
    end

    # Adds a tag to a review
    #
    # @param [Integer] tagId The id of the tag
    # @param [Integer] reviewId The id of the review
    def add_tag(tagId, reviewId)
        db = connect_to_db(DB_PATH)
        db.execute("INSERT INTO review_tag_relation (review_id, tag_id) VALUES (?, ?)", reviewId, tagId)
    end

    # Removes a tag from a review
    #
    # @param [Integer] tagId The id of the tag
    # @param [Integer] reviewId The id of the review
    def remove_tag(tagId, reviewId)
        db = connect_to_db(DB_PATH)
        p db.execute("SELECT * FROM review_tag_relation WHERE tag_id = ? AND review_id = ?", tagId, reviewId)
        db.execute("DELETE FROM review_tag_relation WHERE tag_id = ? AND review_id = ?", tagId, reviewId)
    end

    # Checks if a two strings share any character
    #
    # @param [String] str
    # @param [String] contains
    #
    # @return [Boolean] Whether str shares any characters with contains
    def string_contains_any?(str, contains)
        return (str.split('') & contains.split('')).any?
    end

    # Checks if an attempted login is successful
    #
    # @param [String] login The username or email of a user
    # @param [String] password
    #
    # @return [Boolean] Whether or not the login was successful
    def authenticate_user(login, password) # Login is email or username
        db = connect_to_db(DB_PATH)

        # Check if login is email or username
        userAry = []
        if URI::MailTo::EMAIL_REGEXP.match?(login)
            userAry = db.execute("SELECT * FROM user WHERE email = ?", login)
            userExists = !userAry.empty?
            unless userExists
                session[:loginError] = "That email is not registered"
                return false
            end
        else
            userAry = db.execute("SELECT * FROM user WHERE name = ?", login)
            userExists = !userAry.empty?
            unless userExists
                session[:loginError] = "That user does not exist"
                return false
            end
        end
            
        # Check if password is correct
        user = userAry.first # Should never be empty if this part of the code is reached
        pwDigest = user["pwdigest"]
        pwDigest = BCrypt::Password.new(pwDigest)
        unless pwDigest == password
            session[:registrationError] = "Incorrect password"
            return false
        end
        return true
    end

    # Logs in a user
    #
    # @param [String] login The username or email of the user
    def login_user(login)
        db = connect_to_db(DB_PATH)
        # Check if login is email or username
        user = nil
        if URI::MailTo::EMAIL_REGEXP.match?(login)
            user = db.execute("SELECT * FROM user WHERE email = ?", login).first
        else
            user = db.execute("SELECT * FROM user WHERE name = ?", login).first
        end
        session[:user_id] = user["id"]
    end

    # Registers a user
    #
    # @param [String] username
    # @param [String] email
    # @param [String] password
    def register_user(username, email, password)
        db = connect_to_db(DB_PATH)
        pwDigest = BCrypt::Password.create(password)
        db.execute("INSERT INTO user (name, email, pwdigest) VALUES (?, ?, ?)", username, email, pwDigest)
        login_user(email)
    end

    # Checks if the current user is authorized to alter a category
    #
    # @param [Integer] categoryId
    #
    # @return [Boolean] Whether or not the user is authorized
    def authorize_user_category(categoryId)
        db = connect_to_db(DB_PATH)

        if session[:user_id] == nil
            return false
        end
        userIsAdmin = db.execute("SELECT * FROM user WHERE id = ?", session[:user_id]).first["admin"] == 1
        if (user_is_moderator(categoryId)) or (user_is_admin)
            return true
        end
        return false
    end

    # Checks if the current user is authorized to alter a review
    #
    # @param [Integer] ownerId The owner of the review
    # @param [Integer] categoryId
    #
    # @return [Boolean] Whether or not the user is authorized
    def authorize_user_review(ownerId, categoryId)
        db = connect_to_db(DB_PATH)

        if session[:user_id] == nil
            return false
        end
        if (session[:user_id] == ownerId) or (user_is_moderator(categoryId)) or (user_is_admin)
            return true
        end
        return false
    end

    # Checks if the current user is authorized to alter a sub-review
    #
    # @param [Integer] ownerId The owner of the sub-review
    # @param [Integer] reviewId The id of the review that the sub-review is attached to
    #
    # @return [Boolean] Whether or not the user is authorized
    def authorize_user_sub_review(ownerId, reviewId)
        db = connect_to_db(DB_PATH)

        if session[:user_id] == nil
            return false
        end
        categoryId = db.execute("SELECT * FROM review WHERE id = ?", reviewId).first["category_id"]
        if (session[:user_id] == ownerId) or (user_is_moderator(categoryId)) or (user_is_admin)
            return true
        end

        return false
    end

    # Checks if the current user is a moderator of a given category
    #
    # @param [Integer] categoryId
    #
    # @return [Boolean]
    def user_is_moderator(categoryId)
        db = connect_to_db(DB_PATH)
        moderatorIds = db.execute("SELECT mod_id FROM moderator_category_relation WHERE category_id = ?", categoryId)
        moderatorIdsArray = moderatorIds.map{|id| id["mod_id"]}
        return moderatorIdsArray.include?(session[:user_id])
    end

    # Checks if the current user is the owner of a given review
    #
    # @param [Integer] reviewId
    #
    # @return [Boolean]
    def user_is_review_owner(reviewId)
        db = connect_to_db(DB_PATH)
        review = db.execute("SELECT * FROM review WHERE id = ?", reviewId).first
        ownerId = review["author_id"]
        return session[:user_id] == ownerId
    end

    # Gets all reviews within a category
    #
    # @param [Integer] categoryId
    #
    # @return [Array<Hash>]
    def get_reviews(categoryId)
        db = connect_to_db("db/reviewsplus.db")
        return db.execute("SELECT * FROM review WHERE category_id = ?", categoryId)
    end

    # Gets all sub-reviews of a review
    #
    # @param [Integer] reviewId
    #
    # @return [Array<Hash>]
    def get_sub_reviews(reviewId)
        db = connect_to_db(DB_PATH)
        return db.execute("SELECT * FROM sub_review WHERE review_id = ?", reviewId)
    end
end

# All methods that can be accessed in slim
module SlimHelpers
    # Gets all users from the database
    #
    # @return [Array<Hash>] The users
    def users
        db = connect_to_db(DB_PATH)
        db.execute("SELECT * FROM users")
    end

    # Gets the current logged in user's name
    #
    # @return [String] The name of the user
    def get_user
        if session[:user_id] == nil
            return nil
        end
        db = connect_to_db(DB_PATH)
        user = db.execute("SELECT * FROM user WHERE id = ?", session[:user_id]).first
        return user["name"]
    end

    # Gets all reviews from the database
    #
    # @return [Array<Hash>] The reviews
    def get_all_reviews
        db = connect_to_db(DB_PATH)
        return db.execute("SELECT * FROM review")
    end

    # Gets all categories from the database
    #
    # @return [Array<Hash>] The categories
    def get_categories
        db = connect_to_db(DB_PATH)
        return db.execute("SELECT * FROM category")
    end

    # Gets all categories that the current logged in user is a moderator of
    #
    # @return [Array<Hash>] The categories
    def get_moderated_categories
        if session[:user_id] == nil
            return nil
        end
        db = connect_to_db(DB_PATH)
        moderatedCategoryIds = db.execute("SELECT * FROM moderator_category_relation WHERE mod_id = ?", session[:user_id])
        moderatedCategoryIds.map!{|hash| hash["category_id"]}
        categories = get_categories
        if user_is_admin
            return categories
        end
        categories.select!{|cat| moderatedCategoryIds.include?(cat["id"])}
        return categories
    end

    # Checks whether or not the current logged user is an admin
    #
    # @ return [Boolean] Whether or not the current logged user is an admin
    def user_is_admin
        if session[:user_id] == nil
            return false
        end
        db = connect_to_db(DB_PATH)
        user = db.execute("SELECT * FROM user WHERE id = ?", session[:user_id]).first
        return user["admin"] == 1
    end
end