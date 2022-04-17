require 'uri'

# Ruby

def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

# TODO: tillämpa funktionen
def validate_user_registration(username, email, password, confirm, dbPath)
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

def authenticate_user(login, password, dbPath) # Login is email or username
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

def login_user(login, dbPath)
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

def register_user(username, email, password, dbPath)
    db = connect_to_db(dbPath)
    pwDigest = BCrypt::Password.create(password)
    db.execute("INSERT INTO user (name, email, pwdigest) VALUES (?, ?, ?)", username, email, pwDigest)
    login_user(email, dbPath)
end

def authorize_user(ownerId, moderatorIds, dbPath)
    db = connect_to_db(dbPath)

    userId = session[:user_id]
    userIsAdmin = db.execute("SELECT admin FROM user WHERE id = ?", userId).first == 1
    if userId == nil
        return false
    end
    
    if userId == ownerId or moderatorIds.include?(userId) or userIsAdmin
        return true
    end
    return false
end

# Slim

helpers do
    def users
        db = connect_to_db("db/reviewsplus.db")
        db.execute("SELECT * FROM users")
    end

    def getUser
        session[:user_id]
    end
end