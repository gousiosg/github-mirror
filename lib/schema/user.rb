require 'rubygems'
require 'lazy'

class User < SchemaBase
  extend DB

  attr_reader :timestamp
  attr_reader :login
  attr_reader :id
  attr_reader :name
  attr_reader :company
  attr_reader :location
  attr_reader :email
  attr_reader :hirable
  attr_reader :bio
  attr_reader :public_repos
  attr_reader :public_gists
  attr_reader :created_at

  # Initialize a user object
  #
  # @param [Hash, BSON::OrderedHash] args
  #   An
  #
  # @option args [Integer] :timestamp seconds since the epoch to use as a basis
  #   for all queries. Queries will use the the first user instance before the
  #   provided timestamp as reference for all queries .
  #
  # @raise [ArgumentError]
  #   if timeout is set to false and find is not invoked in a block
  #
  # @raise [RuntimeError]
  #   if given unknown options
  def initialize(args = {})
    super(timestamp)

    @timestamp = args.delete(:timestamp) || Time.now.to_i

    @followers = promise { get_followers }
    @watched_repos = promise { get_watched_repos }

  end

  def self.find_by_uname(uname, timestamp = Time.now.to_i)

  end

  private

  def get_followers

  end

  def get_watched_repos
    DB::watched_col.find({:ght_owner => @login,
                          :ght_ts => {"$lte" => @timestamp}})
  end
end
