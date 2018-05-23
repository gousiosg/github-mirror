require 'test_helper'

class GhtFollowerTest

  describe 'test the user repo methods' do
    around do | test |
      ght_trx do
        test.call
      end
    end

    before do
      @ght = ght
      @db = db
    end

    it 'calls ensure_user_follower method' do
        user = create(:user)
        retval = @ght.ensure_user_follower(user.name, user.name)
      end

      it 'calls ensure_user_follower method with real users' do
        followed = create(:user, db_obj: @db )
        follower_user = create(:user, db_obj: @db )
        follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id, db_obj: @db})

        retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email)
        assert retval
        assert retval[:follower_id].must_equal follower.follower_id
      end

      it 'calls ensure_user_follower method without saved follower' do
        followed = create(:user, db_obj: @db )
        follower_user = create(:user)
        follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id})

        @ght.stubs(:retrieve_user_follower).returns follower
        @ght.stubs(:retrieve_user_byemail).returns nil

        retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email)
        assert retval
        assert retval[:user_id].must_equal followed.id
      end

      it 'calls ensure_user_follower method updates date_created' do
        followed = create(:user, db_obj: @db )
        follower_user = create(:user)
        follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id})

        @ght.stubs(:retrieve_user_follower).returns follower
        @ght.stubs(:retrieve_user_byemail).returns nil
        time_stamp = (Time.now.utc + 1).strftime('%F %T')

        refute follower.created_at == time_stamp
        retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email, time_stamp)
        assert retval[:created_at].strftime('%F %T').must_equal time_stamp
      end

      it 'calls ensure_user_follower method without any follower' do
        followed = create(:user, db_obj: @db )
        follower_user = create(:user)

        @ght.stubs(:retrieve_user_follower).returns nil
        @ght.stubs(:retrieve_user_byemail).returns follower_user
        @ght.expects(:warn).returns("Could not retrieve follower #{follower_user.name_email} for #{followed.name_email}")

        retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email, Time.now.utc.strftime('%F %T'))
        refute retval
      end

      it 'calls ensure_user_followers(followed) method' do
        followed = create(:user, db_obj: @db )
        follower_user = create(:user, db_obj: @db )
        follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id, db_obj: @db})
        @ght.stubs(:retrieve_user_followers).returns [ 'follows' => followed ]

        retval = @ght.ensure_user_followers(followed.name_email)
        assert retval.empty?
      end

      it 'should call ensure_user_following method' do
        following = create(:user, db_obj: @db )
        follower_user = create(:user, db_obj: @db )
        follower = create(:follower, {follower_id: following.id, user_id: following.id, db_obj: @db})
        @ght.stubs(:retrieve_user_following).returns [ 'follows' => following ]

        retval = @ght.ensure_user_following(following.name_email)
        assert retval.empty?
      end
  end
end
