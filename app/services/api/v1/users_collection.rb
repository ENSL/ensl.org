module Api
  module V1
    class UsersCollection < Collection
      def initialize(relation = User.all)
        @relation = relation
      end

      # Execute the Arel query and return rows (arrays)
      def execute_query
        ActiveRecord::Base.connection.select_rows(arel_query.to_sql)
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
        User.arel_table
      end

      def teams_table
        Team.arel_table
      end

      def joins
        [users_table[:team_id].eq(teams_table[:id])]
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

      def arel_query
        users_table
          .project(columns)
          .join(teams_table, Arel::Nodes::OuterJoin)
          .on(joins)
          .order(users_table[:id])
      end

      def map_query
        execute_query.map do |row|
          {
            id: row[5],
            username: row[0],
            steamid: row[1],
            team: {
              name: row[2],
              tag:  row[3],
              logo: row[4]
            }
          }
        end
      end
    end
  end
end
