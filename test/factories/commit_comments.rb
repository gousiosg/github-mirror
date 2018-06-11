FactoryGirl.define do
  factory :commit_comment, :class => OpenStruct do
    skip_create
    id nil
    commit_id { Faker::Number.number(2) }
    user_id { Faker::Number.number(2) }
    body {Faker::Lorem.paragraph}
    line { Faker::Number.number(2) }
    position { Faker::Number.number(2) }
    comment_id { Faker::Number.number(2) }
    created_at { Time.now.utc.strftime('%F %T') }

    transient do
      db_obj nil
    end

    trait :github_comment do
        transient do
          user {}
        end
      end


    after(:create) do | commit_comment, evaluator |
      attributes = apply_overrides_and_transients(:commit_comment, evaluator)
      if commit_comment.db_obj
        commit_comment.id = commit_comment.db_obj[:commit_comments].insert(attributes)
      end
    end
  end
end
