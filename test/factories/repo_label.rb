FactoryGirl.define do
    factory :repo_label, :class => OpenStruct do
      skip_create
      id nil
      repo_id { Faker::Number.number(2) }
      name  {Faker::Name.name}

      transient do
        db_obj nil
      end
  
      trait :github_repo_label do
          transient do
            
          end

          before(:create) do |repo_label, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end  
  
      
      after(:create) do | repo_label, evaluator |
        override_hash = evaluator.instance_variable_get('@overrides')
          if override_hash.key?(:github)
            override_hash.delete(:github)
            override_hash[:name] ||= Faker::Name.name 
            override_hash[:user] ||= { 'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
          end
        
        attributes = apply_overrides_and_transients(:repo_label, evaluator)
        
        if repo_label.db_obj
          repo_label.id = repo_label.db_obj[:repo_labels].insert(attributes) 
        end
      end
    end
  end