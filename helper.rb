# Ruby

def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

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
end