FactoryGirl.define do

  factory :organization_member, :class => OpenStruct do
    skip_create
    org_id {Faker::Number.number(2) }
    user_id {Faker::Number.number(2) }
    created_at { Time.now.utc.strftime('%F %T') }
  end
end
