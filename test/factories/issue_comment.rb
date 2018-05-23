FactoryGirl.define do
    factory :issue_comment, :class => OpenStruct do
      skip_create
      issue_id { Faker::Number.number(4) }
      user_id { Faker::Number.number(4) }
      comment_id { Faker::Number.number(4) }
      created_at { DateTime.now.strftime('%FT%T%:z') }

      transient do
        db_obj nil
      end

      trait :github_comment do
          transient do
            id nil
            user {}
          end
          before(:create) do |issue_coment, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end


      after(:create) do | issue_comment, evaluator |
        override_hash = evaluator.instance_variable_get('@overrides')
          if override_hash.key?(:github)
            override_hash.delete(:github)
            override_hash[:id] ||= override_hash[:comment_id]
            override_hash[:user] ||= { 'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
          end

        attributes = apply_overrides_and_transients(:issue_comment, evaluator)

        if issue_comment.db_obj
          issue_comment.db_obj[:issue_comments].insert(attributes)
        end
      end
    end
  end
