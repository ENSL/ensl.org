# frozen_string_literal: true

module Api
  module V1
    class Collection
      def execute_query
        ActiveRecord::Base.connection.execute(arel_query.to_sql)
      end
    end
  end
end
