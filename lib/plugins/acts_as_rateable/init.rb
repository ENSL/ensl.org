require 'acts_as_rateable'

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Rateable)
