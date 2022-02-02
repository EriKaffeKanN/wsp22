# Ruby

def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

# Slim

helpers do
    def users
        db = connect_to_db("db/reviewsplus.db")
        db.execute("SELECT * FROM users")
    end
end