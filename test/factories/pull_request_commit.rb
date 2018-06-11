
FactoryGirl.define do

    factory :pull_request_commit, :class => OpenStruct do

      skip_create
      pull_request_id nil
      commit_id {Faker::Number.number(2) }

        transient do
            db_obj nil
        end

        trait :github_pr_commit do
          transient do
            id nil
            repo_name {Faker::Name.name }
            owner {Faker::Name.name }
            url {Faker::Internet.url}
            sha { SecureRandom.hex }
          end
          before(:create) do |pull_request_commit, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end

        after(:create) do | pull_request_commit, evaluator |
          override_hash = evaluator.instance_variable_get('@overrides')

          if override_hash.key?(:github)
            override_hash.delete(:github)
            override_hash[:repo_name] ||= Faker::Name.name
            override_hash[:owner] ||= Faker::Name.name

            url = Faker::Internet.url('github.com/repos') + "#{override_hash[:owner]}/#{override_hash[:repo_name]}"
            override_hash[:url] ||= url
          end

          attributes = apply_overrides_and_transients(:pull_request_commit, evaluator)

          if pull_request_commit.db_obj
            pull_request_commit.db_obj[:pull_request_commits].insert(attributes)
          end
        end
      end
    end
