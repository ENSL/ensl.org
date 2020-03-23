class Api::V1::Collection
  def execute_query
    # print arel_query.to_sql
    ActiveRecord::Base.connection.execute(arel_query.to_sql)
  end
end
