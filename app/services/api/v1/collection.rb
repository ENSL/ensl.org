class Api::V1::Collection
  def execute_query
    ActiveRecord::Base.connection.execute(arel_query.to_sql)
  end
end