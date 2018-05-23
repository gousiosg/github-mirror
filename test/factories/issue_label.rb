FactoryGirl.define do
    factory :issue_label, :class => OpenStruct do
      skip_create
      issue_id { Faker::Number.number(2) }
      label_id { Faker::Number.number(2) }

      transient do
        db_obj nil
      end

      trait :github_label do
          transient do
            name nil
          end

          before(:create) do |issue_label, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end


      after(:create) do | issue_label, evaluator |
        override_hash = evaluator.instance_variable_get('@overrides')
          if override_hash.key?(:github)
            override_hash.delete(:github)
            override_hash[:name] ||= Faker::Name.name
            override_hash[:user] ||= { 'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
          end

        attributes = apply_overrides_and_transients(:issue_label, evaluator)

        if issue_label.db_obj
          issue_label.db_obj[:issue_labels].insert(attributes)
        end
      end
    end
  end
