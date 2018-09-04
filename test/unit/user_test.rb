require 'test_helper'

describe 'GhtUser' do
  describe 'ghtorrent transaction test' do
    run_tests_in_transaction

    it 'should create persist a fake user' do
      user = create(:user, db_obj: db)
      assert user
      saved_user = db[:users].where(id: user.id).first
      saved_user[:name].must_equal user.name
    end

    it 'should test the user factory' do
      users_count = db[:users].count
      db.transaction(:rollback=>:always) do
        user1 = create(:user, { name: 'melvin', db_obj: db } )
        user2 = create(:user)

        assert user1.name.must_equal 'melvin'
        refute user1.name == user2.name
        assert user2.db_obj.nil?

        users = db[:users]
        user_count = users.where(:id => user1.id).count
        assert user_count.must_equal 1

        db_user1 = users.where(:id => user1.id).first
        assert user1.name.must_equal db_user1[:name]

        users = db[:users]
        user_count = users.where(:id => user2.id).count
        assert user_count.must_equal 0
      end
      assert db[:users].count == users_count
    end


    it 'should test the ensure_user method' do
      user = create(:user, db_obj: db)
      returned_user = ght.ensure_user(user[:login], false, false)
      assert returned_user
      assert returned_user[:id] == user.id
    end

    it 'ensure_user method should not return a user if given a bad email' do
      user = create(:user) # create a bad email by not saving new user
      assert ght.ensure_user(user.email).nil?
    end

    it 'ensure_user should find correct user if given a name and email' do
      user = create(:user, db_obj: db)
      GHTorrent::Mirror.any_instance.stubs(:ensure_user_byemail).returns(user)
      returned_user = ght.ensure_user("#{user[:login]}<msk999@xyz.com>", false, false)
      assert returned_user[:id] == user[:id]
    end

    it 'ensure_user should not find a user if given a bad user name only' do
      returned_user = ght.ensure_user("~999~$", false, false)
      assert returned_user.nil?
    end

    it 'should return a user given an email and user' do
      user = create(:user, db_obj: db)
      email = user.email
      returned_user = ght.ensure_user_byemail(email, user.login)
      assert returned_user[:email] == email
    end

    it 'should return a user given a bad email and valid user' do
      user = create(:user, db_obj: db)
      fake_email = Faker::Internet.email

      ght.stubs(:retrieve_user_byemail).returns nil
      returned_user = ght.ensure_user_byemail(fake_email, user.name)

      assert returned_user
      assert returned_user[:email] == fake_email
      assert returned_user[:name] == user.name
    end

    it 'should call ensure_user_byuname method' do
      user = create(:user, type: 'User')
      ght.stubs(:retrieve_user_byusername).returns user
      geoLocate = OpenStruct.new(:long => Faker::Number.number(2), :lat => Faker::Number.number(2),
                                 :country_code => 'US', :state => 'MA', :city => 'Watertown')

      ght.stubs(:geolocate).returns geoLocate
      ght.expects(:info).returns("Added user #{user}")

      retval = ght.ensure_user_byuname(user.name_email)
    end

    it 'should call ensure_user_byuname method with empty email' do
      user = create(:user, {email: '', type: 'User'})
      ght.stubs(:retrieve_user_byusername).returns user
      geoLocate = OpenStruct.new(:long => Faker::Number.number(2), :lat => Faker::Number.number(2),
                                 :country_code => 'US', :state => 'MA', :city => 'Watertown')

      ght.stubs(:geolocate).returns geoLocate
      ght.expects(:info).returns("Added user #{user}")

      retval = ght.ensure_user_byuname(user.name)
    end
  end
end

