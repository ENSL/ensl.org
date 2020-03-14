class HasViewCountGenerator < Rails::Generator::Base 
  def manifest 
    record do |m| 
      m.migration_template 'migration.rb', 'db/migrate'
      m.template 'model.rb', 'app/models/view_count.rb'
    end 
  end
  
  def file_name
    "has_view_count_migration"
  end
end
