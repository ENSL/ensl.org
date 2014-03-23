class Array
	def mda(*mds)
		count = -1
		
		mdarray = lambda { |*ds| 
			Array.new( ds.shift || 0 ).collect {
				x = mdarray[*ds] unless ds.empty?
				if x == nil then count += 1; x = self.at(count); end
				x
			}
		}
		
		mdarray.call(*mds)    
	end
end