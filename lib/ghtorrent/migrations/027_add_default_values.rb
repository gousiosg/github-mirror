require 'sequel'

Sequel.migration do

  up do
    puts 'Adding fake user and project entries '
    self[:users].insert(
      :id => -1,
      :login => '0xnoone',
      :email => 'no@nowhere.noplace',
      :name => 'Fake entry to indicate a missing user previously existing')

    self[:projects].insert(
        :id => -1,
        :name => 'noproject',
        :owner_id => -1,
        :description => 'Fake entry to indicate a previously existing but currently absent repo')
  end

  down do
    puts 'Dropping fake user and project entries '
    DB[:projects].where(:id => -1).delete
    DB[:users].where(:id => -1).delete
  end

end
