
require File.join(File.dirname(__FILE__), 'lib', 'acts_as_readable')
require File.join(File.dirname(__FILE__), 'lib', 'reading')
require File.join(File.dirname(__FILE__), 'lib', 'user_with_readings')

ActiveRecord::Base.send :include, ActiveRecord::Acts::Readable
