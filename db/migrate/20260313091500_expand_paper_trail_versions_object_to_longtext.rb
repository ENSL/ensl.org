class ExpandPaperTrailVersionsObjectToLongtext < ActiveRecord::Migration[8.1]
  def up
    return unless mysql_adapter?
    return unless table_exists?(:versions)

    promote_to_longtext(:object)
    promote_to_longtext(:object_changes) if column_exists?(:versions, :object_changes)
  end

  def down
    return unless mysql_adapter?
    return unless table_exists?(:versions)

    demote_to_text(:object) if column_exists?(:versions, :object)
    demote_to_text(:object_changes) if column_exists?(:versions, :object_changes)
  end

  private

  def promote_to_longtext(column_name)
    column = connection.columns(:versions).find { |candidate| candidate.name == column_name.to_s }
    return if column&.sql_type.to_s.downcase.include?('longtext')

    execute "ALTER TABLE versions MODIFY #{column_name} LONGTEXT"
  end

  def demote_to_text(column_name)
    execute "ALTER TABLE versions MODIFY #{column_name} TEXT"
  end

  def mysql_adapter?
    connection.adapter_name.to_s.downcase.include?('mysql')
  end
end
