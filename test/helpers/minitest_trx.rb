class Db_Provider
  class << self
    def ght
      @ght ||= GHTorrent::Mirror.new(1)
    end

    def db
      @db ||= ght.db
    end
  end
end

def db
  Db_Provider.db
end

def ght
  Db_Provider.ght
end

def ght_trx(&block)
  db.transaction(:rollback=>:always) do
    block.call
  end
end
