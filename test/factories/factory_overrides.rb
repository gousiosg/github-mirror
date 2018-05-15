class FactoryGirl::SyntaxRunner
# method to apply overrides to newly created object
  # so we can get a correct hash to insert into the table
  def apply_overrides_and_transients(mygirl, evaluator)
    attributes = evaluator.instance_variable_get('@overrides')
    instance = evaluator.instance_variable_get('@instance')
    fields = instance.instance_variable_get("@table")
    
    transient_keys = attributes.keys - fields.keys 
    overrides = evaluator.methods(false) - transient_keys - [:db_obj]
    hashed = instance.to_h

    apply_transients(instance, attributes, transient_keys) if transient_keys.any?
    
    return hashed if overrides.empty?
    slices = attributes.slice(*overrides)
    hashed.merge slices
  end

  def apply_transients(instance, evaluator, transient_keys)
    transient_keys.each do |key| 
        instance[key] = eval 'evaluator[:' + key.to_s + ']' 
    end
  end
end