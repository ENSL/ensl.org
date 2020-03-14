require 'acts_as_readable'

ActiveRecord::Base.send :include, ActiveRecord::Acts::Readable
