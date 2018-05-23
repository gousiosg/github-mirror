require 'test_helper'

class GhtFollowerlTest

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

    it 'should call the ensure orgs method with a regular user' do
        user = create(:user, db_obj: @db)
        @ght.stubs(:retrieve_orgs).returns([user])
        retval = @ght.ensure_orgs(user.name)
        assert retval.empty?
       end

       it 'should call the ensure orgs method with an organization' do
         fake_name_login = Faker::Name.first_name
         user = create(:user, {name: fake_name_login, login: fake_name_login, type: 'org', db_obj: @db})
         org_member = create(:user,db_obj: @db)
         @ght.stubs(:retrieve_orgs).returns([user])
         @ght.stubs(:retrieve_org_members).returns([user])
         @ght.stubs(:ensure_user).returns(user)
         retval = @ght.ensure_orgs(user)
         assert retval && retval[0][:user_id] == user.id
      end
  end
end
