module DB

  def DB.db
    settings = YAML::load_file settings
    db = Mongo::Connection.new(settings['mongo']['host'],
                               settings['mongo']['port']).db(settings['mongo']['db'])
    #@db.authenticate(@settings['mongo']['username'],
    #                 @settings['mongo']['password'])
    db
  end

  def DB.commits_col
    db.collection(@settings['mongo']['commits'])
  end

  def DB.commits_col_v3
    db.collection(@settings['mongo']['commitsv3'])
  end

  def DB.watched_col
    db.collection(@settings['mongo']['watched'])
  end

  def DB.events_col
    db.collection(@settings['mongo']['events'])
  end

  def DB.followed_col
    db.collection(@settings['mongo']['followed'])
  end

  def DB.followers_col
    db.collection(@settings['mongo']['followers'])
  end

  def users_col
    @db.collection(@settings['mongo']['users'])
  end

  def repos_col
    @db.collection(@settings['mongo']['repos'])
  end
end