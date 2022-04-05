# Ruby

def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

def register_user(userName, email, password, dbPath)
{
    db = connect_to_db(dbPath)
    pwDigest = BCrypt::Password.create(password)
    db.execute("INSERT INTO user (name, email, password) VALUES (?, ?, ?)", userName, email, pwDigest)
}

def authenticate(ownerId, reqPermissionLevel)
    db = connect_to_db()

    userId = session[:user_id]
    userPermissionLevel = db.execute("SELECT permission FROM user WHERE user_id = ?", userId).first
    if userId == nil
        return false
    end
    
    if userId == ownerId or userPermissionLevel >= reqPermissionLevel
        return true
    end
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