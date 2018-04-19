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
        if user.db_obj
          attributes = apply_overrides(:user, evaluator)
          user.id = user.db_obj[:users].insert(attributes) 
        end
      end
    end
  end

  # method to apply overrides to newly created object
  # so we can get a correct hash to insert into the table
  def apply_overrides(mygirl, evaluator)
    attributes = evaluator.instance_variable_get('@overrides')
    overrides = evaluator.methods(false)-[:db_obj]  
    hashed = attributes_for(mygirl).to_h

    return hashed if overrides.empty?
    slices = attributes.slice(*overrides)
    hashed.merge slices
  end