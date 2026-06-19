class Array
  def mda(*mds)
    count = -1

    mdarray = lambda { |*ds|
      Array.new(ds.shift || 0).collect do
        x = mdarray[*ds] unless ds.empty?
        if x.nil? then count += 1
                       x = at(count)
        end
        x
      end
    }

    mdarray.call(*mds)
  end
end
