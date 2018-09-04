FactoryGirl.define do

    factory :watcher, :class => OpenStruct do
      skip_create
        repo_id {Faker::Number.number(2) }
        user_id {Faker::Number.number(2) }
        created_at { Time.now.utc.strftime('%F %T') }

        transient do
            db_obj nil
        end

        after(:create) do | watcher, evaluator |
          attributes = apply_overrides_and_transients(:watcher, evaluator)

          if watcher.db_obj
            attributes = attributes.except(:id)
            watcher.id = watcher.db_obj[:watchers].insert(attributes)
          end
        end
      end
    end
