require 'uri'

# Ruby

def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

def get_category(categoryId)
    db = connect_to_db(dbPath)
    return db.execute("SELECT * FROM category WHERE id = ?", categoryId).first
end

def update_category(categoryId, newName)
    db = connect_to_db(dbPath)
    db.execute("UPDATE category SET name = ? WHERE id = ?", newName, categoryId)
end

def delete_category(categoryId)
    db = connect_to_db(dbPath)
    db.execute("DELETE FROM category WHERE id = ?", categoryId)
    db.execute("DELETE FROM review WHERE category_id = ?", categoryId)
    db.execute("DELETE FROM moderator_category_relation WHERE category_id = ?", categoryId)
    db.execute("DELETE FROM tags WHERE category_id = ?", categoryId)
end

def create_new_category(name)
    db = connect_to_db(dbPath)
    db.execute("INSERT INTO category (name) VALUES (?)", name)
    categoryId = db.execute("SELECT last_insert_rowid()").first["last_insert_rowid()"]
    db.execute("INSERT INTO moderator_category_relation (mod_id, category_id) VALUES (?, ?)", session[:user_id], categoryId)
end

def create_new_tag(name, categoryId)
    db = connect_to_db(dbPath)
    db.execute("INSER INTO tag (name, category_id) VALUES (?, ?)", name, categoryId)
end

def get_tags(reviewId)
    db = connect_to_db(dbPath)
    tags = db.execute("SELECT * FROM review_tag_relation INNER JOIN tag ON review_tag_relation.tag_id WHERE review_id = ?", reviewId)
    tags.map!{|t| t["name"]}
    return tags
end

def get_review(reviewId)
    db = connect_to_db(dbPath)
    return db.execute("SELECT * FROM review WHERE id = ?", reviewId).first
end

def delete_review(reviewId)
    db = connect_to_db(dbPath)
    db.execute("DELETE FROM review WHERE id = ?", reviewId)
end

def create_new_review(title, body, rating, ownerId, categoryId)
    db = connect_to_db(dbPath)
    db.execute("INSERT INTO review (title, body, rating, author_id, category_id) VALUES (?, ?, ?, ?, ?)", title, body, rating, ownerId, categoryId)
end

def validate_user_registration(username, email, password, confirm)
    db = connect_to_db(dbPath)

    nameAldreadyExists = !db.execute("SELECT * FROM user WHERE name = ?", username).empty?
    if nameAldreadyExists
        session[:loginError] = "The name already exists"
        return false
    end

    # Email
    emailCorrectlyFormatted = URI::MailTo::EMAIL_REGEXP.match?(email)
    emailAlreadyExists = !db.execute("SELECT * FROM user WHERE email = ?", email).empty?
    if !emailCorrectlyFormatted
        session[:loginError] = "Use a real email adress"
        return false
    elsif emailAlreadyExists
        session[:loginError] = "That email already exists"
        return false
    end
    # Password
    if password != confirm
        session[:loginError] = "Passwords did not match each other"
        return false
    elsif password.length < 8
        session[:loginError] = "Password needs to be 8 characters or more"
        return false
    elsif !string_contains_any?(password, "1234567890")
        session[:loginError] = "Password needs to contain at least 1 numerical value"
        return false
    end
    return true
end

def string_contains_any?(str, contains)
    return (str.split('') & contains.split('')).any?
end

def authenticate_user(login, password) # Login is email or username
    db = connect_to_db(dbPath)

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
        session[:loginError] = "Incorrect password"
        return false
    end
    return true
end

def login_user(login)
    db = connect_to_db(dbPath)
    # Check if login is email or username
    user = nil
    if URI::MailTo::EMAIL_REGEXP.match?(login)
        user = db.execute("SELECT * FROM user WHERE email = ?", login).first
    else
        user = db.execute("SELECT * FROM user WHERE name = ?", login).first
    end
    session[:user_id] = user["id"]
end

def register_user(username, email, password)
    db = connect_to_db(dbPath)
    pwDigest = BCrypt::Password.create(password)
    db.execute("INSERT INTO user (name, email, pwdigest) VALUES (?, ?, ?)", username, email, pwDigest)
    login_user(email)
end

def authorize_user_category(categoryId)
    db = connect_to_db(dbPath)

    if session[:user_id] == nil
        return false
    end
    userIsAdmin = db.execute("SELECT * FROM user WHERE id = ?", session[:user_id]).first["admin"] == 1
    if (userIsModerator(categoryId)) or (userIsAdmin)
        return true
    end
    return false
end

def authorize_user_review(ownerId, categoryId)
    db = connect_to_db(dbPath)

    if session[:user_id] == nil
        return false
    end
    userIsAdmin = db.execute("SELECT * FROM user WHERE id = ?", session[:user_id]).first["admin"] == 1
    if (session[:user_id] == ownerId) or (userIsModerator(categoryId)) or (userIsAdmin)
        return true
    end
    return false
end

def user_is_moderator(categoryId)
    db = connect_to_db(dbPath)
    moderatorIds = db.execute("SELECT mod_id FROM moderator_category_relation WHERE category_id = ?", categoryId)
    moderatorIdsArray = moderatorIds.map{|id| id["mod_id"]}
    return moderatorIdsArray.include?(session[:user_id])
end

def user_is_review_owner(reviewId)
    db = connect_to_db(dbPath)
    review = db.execute("SELECT * FROM review WHERE id = ?", reviewId).first
    ownerId = review["author_id"]
    return session[:user_id] == ownerId
end

def get_reviews(categoryId)
    db = connect_to_db("db/reviewsplus.db")
    return db.execute("SELECT * FROM review WHERE category_id = ?", categoryId)
end

# Slim

helpers do
    def users
        db = connect_to_db(dbPath)
        db.execute("SELECT * FROM users")
    end

    def get_user
        if session[:user_id] == nil
            return nil
        end
        db = connect_to_db(dbPath)
        user = db.execute("SELECT * FROM user WHERE id = ?", session[:user_id]).first
        return user["name"]
    end

    def get_categories
        db = connect_to_db(dbPath)
        return db.execute("SELECT * FROM category")
    end

    def get_moderated_categories
        if session[:user_id] = nil
            return nil
        end
        db = connect_to_db(dbPath)
        return db.execute("SELECT * FROM category WHERE id = ?", session[:user_id])
    end

    def user_is_admin
        if session[:user_id] == nil
            return false
        end
        db = connect_to_db(dbPath)
        user = db.execute("SELECT * FROM user WHERE id = ?", session[:user_id]).first
        return user["admin"] == 1
    end
end