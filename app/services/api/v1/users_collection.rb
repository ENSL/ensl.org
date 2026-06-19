# frozen_string_literal: true

module Api
  module V1
    class UsersCollection < Collection
      def initialize(relation = User.all)
        super()
        @relation = relation
      end

      # Execute the query and return rows (arrays)
      def execute_query
        relation_query.pluck(*columns)
      end

      # Return Ruby hash (not a JSON string)
      def data
        { users: map_query }
      end

      def self.as_json
        new.data
      end

      private

      def users_table
        @relation.arel_table
      end

      def teams_table
        Team.arel_table
      end

      def columns
        [
          users_table[:username],  # 0
          users_table[:steamid],   # 1
          teams_table[:name],      # 2
          teams_table[:tag],       # 3
          teams_table[:logo],      # 4
          users_table[:id]         # 5
        ]
      end

      def relation_query
        @relation.left_outer_joins(:team).order(users_table[:id])
      end

      def map_query
        execute_query.map do |row|
          {
            id: row[5],
            username: row[0],
            steamid: row[1],
            team: {
              name: row[2],
              tag: row[3],
              logo: row[4]
            }
          }
        end
      end
    end
  end
end
