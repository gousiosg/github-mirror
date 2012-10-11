require 'json'
require 'bson'

class BSON::OrderedHash

  # Convert a BSON result to a +Hash+
  def to_h
    inject({}) do |acc, element|
      k, v = element;
      acc[k] = if v.class == Array then
                 v.map{|x| if x.class == BSON::OrderedHash then x.to_h else x end}
               elsif v.class == BSON::OrderedHash then
                 v.to_h
               else
                 v
               end;
      acc
    end
  end

  def to_json
    to_h.to_json
  end
end
