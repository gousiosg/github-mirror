
FactoryGirl.define do

    factory :pull_request, :class => OpenStruct do

      skip_create
        id nil
        head_repo_id nil
        base_repo_id {Faker::Number.number(4) }
        head_commit_id nil
        base_commit_id {Faker::Number.number(4) }
        pullreq_id {Faker::Number.number(4) }
        intra_branch false

        transient do
            db_obj nil
        end

        trait :github_pr do
          transient do
            base {}
            head {}
            user {}
            merged_at nil
            closed_at nil
            number {Faker::Number.number(4) }
            created_at nil
          end

          before(:create) do |pull_request, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end

        after(:create) do | pull_request, evaluator |
          override_hash = evaluator.instance_variable_get('@overrides')
          if override_hash.key?(:github)
            override_hash.delete(:github)

            override_hash[:base] ||= { 'repo' => { 'owner' => { 'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" },
            'name' => Faker::Name.name }, 'sha' => SecureRandom.hex }

            override_hash[:head]  ||=  override_hash[:base]
            override_hash[:user] ||= { 'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }

            override_hash[:merged_at] ||= nil
            override_hash[:closed_at] ||= nil

            override_hash[:number] ||= override_hash[:pullreq_id]
            override_hash[:created_at] ||= Time.now.utc.strftime('%F %T')
          end

          attributes = apply_overrides_and_transients(:pull_request, evaluator)

          if pull_request.db_obj
            attributes = attributes.except(:id)
            pull_request.id = pull_request.db_obj[:pull_requests].insert(attributes)
          end
        end
      end
    end
