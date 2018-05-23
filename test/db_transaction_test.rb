require 'test_helper'
require 'byebug'

describe GHTorrent::Mirror do
    describe 'testing transaction around method' do
      around do | test |
        ght_trx do
          test.call
        end
      end

      before do
        @ght = ght
        @db = db
      end

      it 'should create a user record mini_it method' do
        @user = create(:user, {id: 999999, db_obj: @db})
        @user_id = @user.id

        puts "Check user.id --> #{@user.id}"

        assert @user.id

        # find record in db.  It should not exist
        user = db[:users].where(:id => @user.id).first
        refute user.nil?
      end
  end

  describe 'rollback should have taken place' do
    it 'should have rolled back user record' do
        user = db[:users].where(:id => 999999).first
        assert user.nil?
      end
    end
end
