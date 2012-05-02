class Team < SchemaBase
  extend DB

  attr_reader :timestamp
  attr_reader :id

  attr_reader :name
  attr_reader :members_count
  attr_reader :repos_count

  def initialize(id, timestamp = Time.now.to_i)
    raise new Exception("Team id is empty") if id.nil?

    @timestamp = timestamp
    @id = id
  end

  def members

  end

end