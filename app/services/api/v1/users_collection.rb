module Api
  module V1
    class UsersCollection < Collection
      # Accept an optional AR relation for easier testing
      def initialize(relation = User.all)
        @relation = relation
      end

      # Return an array of users (simple behavior for specs)
      def execute_query
        @relation.to_a
      end

      def data
        { users: execute_query }
      end

      def self.as_json
        new.data.to_json
      end

      private

      def users_table
        User.arel_table
      end

      def teams_table
        Team.arel_table
      end

      def joins
        [
          users_table[:team_id].eq(teams_table[:id])
        ]
      end

      def columns
        [
          users_table[:username],
          users_table[:steamid],
          teams_table[:name],
          teams_table[:tag],
          teams_table[:logo],
          users_table[:id]
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
              tag: row[3],
              logo: row[4]
            }
          }
        end
      end
    end
  end
end
