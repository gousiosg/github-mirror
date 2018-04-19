FactoryGirl.define do
    
    factory :project, :class => OpenStruct do
      skip_create
        id nil
        owner_id  Faker::Number.number(2) 
        name Faker::Name.name 
        description Faker::Lorem.paragraph
        language Faker::ProgrammingLanguage.name 
        created_at DateTime.now 
        forked_from nil
        deleted false
        updated_at DateTime.now

        transient do
            db_obj nil
        end

      after(:create) do | project, evaluator |
        project.db_obj = evaluator.db_obj 
        if project.db_obj
          attributes = apply_overrides(:project, evaluator)
          project.id = project.db_obj[:projects].insert(attributes) 
        end
      end
    end
  end

  # method to apply overrides to newly created object
  # so we can get a correct hash to insert into the table
  def apply_overrides(mygirl, evaluator)
    attributes = evaluator.instance_variable_get('@overrides')
    overrides = evaluator.methods(false)-[:db_obj]  
    hashed = attributes_for(mygirl).to_h
    return hashed if overrides.empty?
    
    slices = attributes.slice(*overrides)
    hashed.merge slices
  end