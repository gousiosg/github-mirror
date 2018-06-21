
FactoryGirl.define do

    factory :pull_request_comment, :class => OpenStruct do

      skip_create
      pull_request_id nil
      user_id {Faker::Number.number(2) }
      comment_id {Faker::Number.number(2) }
      position {Faker::Number.number(2)}
      body {Faker::Lorem.sentence}
      commit_id {Faker::Number.number(2) }
      created_at { Time.now.utc.strftime('%F %T') }

        transient do
            db_obj nil
        end

        trait :github_pr_comment do
          transient do
            id nil
            user {}
            original_position {Faker::Number.number(2)}
            original_commit_id {Faker::Number.number(2)}

          end
          before(:create) do |pull_request_comment, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end

        after(:create) do | pull_request_comment, evaluator |
          override_hash = evaluator.instance_variable_get('@overrides')

          if override_hash.key?(:github)
            override_hash.delete(:github)

            override_hash[:id] ||= override_hash[:comment_id]
            override_hash[:user] ||= {'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }

            override_hash[:original_position] ||= override_hash[:position]
            override_hash[:original_commit_id] ||= override_hash[:commit_id]
          end

          attributes = apply_overrides_and_transients(:pull_request_comment, evaluator)

          if pull_request_comment.db_obj
            attributes = attributes.except(:id)
            pull_request_comment.db_obj[:pull_request_comments].insert(attributes)
          end
        end
      end
    end
