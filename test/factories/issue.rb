
FactoryGirl.define do

    factory :issue, :class => OpenStruct do

      skip_create
      id nil
      repo_id nil
      reporter_id nil
      assignee_id nil
      pull_request 0
      pull_request_id nil
      created_at { DateTime.now.strftime('%FT%T%:z') }
      issue_id {Faker::Number.number(2) }

        transient do
            db_obj nil
        end

        trait :github_issue do
          transient do
            number nil
            user {}
            assignee {}
            owner {Faker::Name.name }
          end
          before(:create) do |issue, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end

        after(:create) do | issue, evaluator |
          override_hash = evaluator.instance_variable_get('@overrides')

          if override_hash.key?(:github)
            override_hash.delete(:github)
            override_hash[:number] ||= override_hash[:issue_id]
            override_hash[:user] ||= {'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
            override_hash[:assignee] ||= {'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
            override_hash[:owner] ||= Faker::Name.name

            url = Faker::Internet.url('github.com/repos/',
                      "#{override_hash[:owner]}/#{Faker::Internet.user_name}")
            override_hash[:url] ||= url
            override_hash[:user] ||= {'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
          end

          attributes = apply_overrides_and_transients(:issue, evaluator)
          if issue.db_obj
            issue.id = issue.db_obj[:issues].insert(attributes)
          end
        end
      end
    end
