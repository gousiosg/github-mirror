require 'mongo'

module GHTorrent
  class MongoPersister
    include GHTorrent::Settings
    include GHTorrent::Logging

    LOCALCONFIG = {
        :mongo_host => "mongo.host",
        :mongo_port => "mongo.port",
        :mongo_db => "mongo.db",
        :mongo_username => "mongo.username",
        :mongo_passwd => "mongo.password"
    }

    attr_reader :settings

    def initialize(set)
      merge LOCALCONFIG
      @settings = set
      @mongo = Mongo::Connection.new(config(:mongo_host),
                                     config(:mongo_port))\
                                .db(config(:mongo_db))
      @enttodb = {
          :users => get_collection("users"),
          :commits => get_collection("commits"),
          :repos => get_collection("repos"),
          :followers => get_collection("followers")
      }
    end

    def get_collection(col)
      @mongo.collection(col.to_s)
    end

    def store(entity, data = {})

      col = @enttodb[entity]

      if col.nil?
        raise GHTorrentException.new("Entity #{entity} not supported yet")
      end

      col.insert(data)

    end

    def retrieve(entity, query = {})

      col = @enttodb[entity]

      if col.nil?
        raise GHTorrentException.new("Entity #{entity} not supported yet")
      end

      result = col.find(query)
      result.to_a.map { |r| r.to_h }
    end

  end
end

class BSON::OrderedHash
  def to_h
    inject({}) { |acc, element| k, v = element; acc[k] = (
    if v.class == BSON::OrderedHash then
      v.to_h
    else
      v
    end); acc }
  end

  def to_json
    to_h.to_json
  end
end