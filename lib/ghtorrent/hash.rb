class Hash
  def merge_recursive(o, overwrite = true)
    merge(o) do |_,x,y|
      if x.respond_to?(:merge_recursive) && y.is_a?(Hash)
        x.merge_recursive(y)
      else
        if overwrite then y else [x, y].flatten.uniq end
      end
    end
  end
end