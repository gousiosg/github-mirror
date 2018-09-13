require 'test_helper'

describe 'OrgTest' do
  describe 'test the user repo methods' do
    run_tests_in_transaction

    it 'should call the ensure orgs method with a regular user' do
      user = create(:user, db_obj: db)
      ght.stubs(:retrieve_orgs).returns([user])
      retval = ght.ensure_orgs(user.name)
      assert retval.empty?
    end

    it 'should call the ensure orgs method with an organization' do
      fake_name_login = Faker::Name.first_name
      user = create(:user, {name: fake_name_login, login: fake_name_login, type: 'ORG', db_obj: db})
      org_member = create(:user,db_obj: db)
      ght.stubs(:retrieve_orgs).returns([user])
      ght.stubs(:retrieve_org_members).returns([user])
      ght.stubs(:ensure_user).returns(user)
      retval = ght.ensure_orgs(user)
      assert retval && retval[0][:user_id] == user.id
    end
  end
end
