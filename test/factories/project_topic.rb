FactoryGirl.define do
  factory :project_topic, :class => OpenStruct do
    skip_create
    project_id { Faker::Number.number(2) }
    topic_name { Faker::Name.name }
    deleted false
    created_at { Time.now.utc.strftime('%F %T') }
  end
end
