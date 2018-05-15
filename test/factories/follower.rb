FactoryGirl.define do
    
    factory :follower, :class => OpenStruct do
      skip_create
        follower_id {Faker::Number.number(2) }
        user_id nil
        created_at {DateTime.now.strftime('%FT%T%:z')  }
  
        transient do
            db_obj nil
        end
  
        after(:create) do | follower, evaluator |
          attributes = apply_overrides_and_transients(:follower, evaluator)
  
          if follower.db_obj
            follower.id = follower.db_obj[:followers].insert(attributes) 
          end
        end
      end
    end
    