
FactoryGirl.define do

    factory :issue_event, :class => OpenStruct do

      skip_create
      event_id {Faker::Number.number(4) }
      issue_id {Faker::Number.number(4) }
      actor_id nil
      action {Faker::Lorem.paragraph}
      action_specific {Faker::Lorem.word}
      created_at { Time.now.utc.strftime('%F %T') }

        transient do
            db_obj nil
        end

        trait :github_issue_event do
          transient do
            id nil
            actor {}
            event nil
            commit_id nil
          end
          before(:create) do |issue_event, evaluator |
            override_hash = evaluator.instance_variable_get('@overrides')
            override_hash[:github] = {}
          end
        end

        after(:create) do | issue_event, evaluator |
          override_hash = evaluator.instance_variable_get('@overrides')

          if override_hash.key?(:github)
            override_hash.delete(:github)
            override_hash[:id] ||= override_hash[:event_id]

            override_hash[:commit_id] ||= Faker::Number.number(4)
            override_hash[:actor] ||= { 'login' => "#{Faker::Internet.user_name}<#{Faker::Internet.email}>" }
            override_hash[:event] ||= 'referenced'
          end

          attributes = apply_overrides_and_transients(:issue_event, evaluator)
          if issue_event.db_obj
            attributes = attributes.except(:id)
            issue_event.db_obj[:issue_events].insert(attributes)
          end
        end
      end
    end
