module Citrus
  module HasViewCount
  	
		def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods    
    	
    	def has_view_count
        has_many :view_counts, :as => :viewable, :dependent => :destroy
        include Citrus::HasViewCount::InstanceMethods
      end
      
  	end
  	
    module InstanceMethods
    
    	def record_view_count(ip_address, logged_in = false)
      	self.view_counts.create(:viewable => self, :ip_address => ip_address, :logged_in => logged_in)
      	return self   
    	end
    	
    	def view_count
    		self.view_counts.length
    	end
    	    	
    	def view_count_string(str = "view")
    		return "#{view_count} #{str.singularize}" if view_count == 1
    		return "#{view_count} #{str.pluralize}" unless view_count == 1
    	end
 
    end
    
	end
end
ActiveRecord::Base.send(:include, Citrus::HasViewCount)