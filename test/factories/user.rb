FactoryGirl.define do
    
    factory :user, :class => OpenStruct do
      skip_create
        id nil
        login Faker::Internet.user_name
        name  Faker::Name.name
        email Faker::Internet.email
        company nil
        fake false
        deleted false
        long nil
        lat nil
        country_code nil
        state nil
        city nil
        location nil
        created_at DateTime.now

        transient do
          name_email nil 
          db_obj nil
        end

      after(:create) do | user, evaluator |
        user.name_email = "#{user.name}<#{user.email}>" 
        user.db_obj = evaluator.db_obj 
        hashed = attributes_for(:user).to_h
        user.id = user.db_obj[:users].insert(hashed) if user.db_obj
      end
    end
  end