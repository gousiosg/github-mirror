FactoryGirl.define do

  factory :project, :class => OpenStruct, aliases: [:repo] do
    skip_create
      id nil
      url {Faker::Internet.url('github.com/repos/',
        "#{Faker::Internet.user_name}<#{Faker::Internet.email}>/#{Faker::Internet.user_name}")}
      owner_id  {Faker::Number.number(4) }
      name { Faker::Name.name }
      description {Faker::Lorem.paragraph[0..254]}
      language {Faker::ProgrammingLanguage.name }
      created_at { Time.now.utc.strftime('%F %T') }
      forked_from nil
      deleted false
      updated_at { Time.now.utc.strftime('%F %T') }

      transient do
          db_obj nil
      end

      trait :github_project do
        transient do
          owner {}
          parent {}
          full_name nil
        end

        before(:create) do |project, evaluator |
          # derive project name from url
          project.name = project.url.split(/\//)[5]
          override_hash = evaluator.instance_variable_get('@overrides')
          override_hash[:github] = {}
        end
      end

      after(:create) do | project, evaluator |
        override_hash = evaluator.instance_variable_get('@overrides')

        if override_hash[:owner]
          url_split = override_hash[:url].split(/\//)
          override_hash[:url] = "#{url_split[0..3].join('/')}/#{override_hash[:owner]['login']}/#{url_split[5]}"
          project.url = override_hash[:url]
        end
        if override_hash.key?(:github)
          override_hash.delete(:github)
        end

        attributes = apply_overrides_and_transients(:project, evaluator)
        if project.db_obj
          attributes = attributes.except(:id)
          project.id = project.db_obj[:projects].insert(attributes)
        end
      end
    end
  end
