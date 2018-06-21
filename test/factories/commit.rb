
FactoryGirl.define do

  factory :commit, :class => OpenStruct, aliases: [:sha] do
    skip_create
      id nil
      sha { SecureRandom.hex }
      author_id nil
      committer_id nil
      project_id { Faker::Number.number(2) }
      created_at { Time.now.utc.strftime('%F %T') }

      transient do
          db_obj nil
      end

      trait :github_commit do
        transient do
          author nil
          committer nil
          commit  {}
          parents []
        end
      end

      after(:create) do | commit, evaluator |
        override_hash = evaluator.instance_variable_get('@overrides')
        if override_hash.key?(:github)
          override_hash.delete(:github)
          override_hash[:id] ||= override_hash[:comment_id]
          override_hash[:user] ||= { 'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
        end


        attributes = apply_overrides_and_transients(:commit, evaluator)
        if commit.db_obj
          attributes = attributes.except(:id)
          commit.id = commit.db_obj[:commits].insert(attributes)
        end
      end
    end
  end
