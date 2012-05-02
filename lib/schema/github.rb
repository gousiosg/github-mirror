class Github < SchemaBase
  extend DB

  def initialize(timestamp = Time.now.to_i)
    super(timestamp)
  end

  def get_users

  end

end
