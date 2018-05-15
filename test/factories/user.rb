FactoryGirl.define do

  factory :user, :class => OpenStruct do
    skip_create
    id nil
    name  {Faker::Name.name}
    email {Faker::Internet.email}
    login {"#{name}<#{email}>"}
    company nil
    type 'people'
    fake false
    deleted false
    long nil
    lat nil
    country_code nil
    state nil
    city nil
    location nil
    created_at {DateTime.now.strftime('%FT%T%:z')}

      transient do
        name_email {nil }
        db_obj {nil}

        before(:create) do |issue_coment, evaluator |
          override_hash = evaluator.instance_variable_get('@overrides')
          override_hash[:github] = {}
        end
      end

      after(:create) do | user, evaluator |
        override_hash = evaluator.instance_variable_get('@overrides')
        if override_hash.key?(:github)
          override_hash.delete(:github)
          override_hash[:name_email] ||= "#{override_hash[:name]}<#{override_hash[:email]}>" 
        end

        attributes = apply_overrides_and_transients(:user, evaluator)
        
        if user.db_obj
          user.id = user.db_obj[:users].insert(attributes) 
        end
      end
    end
  end
