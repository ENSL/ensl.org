module Api
  module V1
    class TeamsCollection < Api::V1::Collection
      def self.as_json
        new.data.to_json
      end

      def data
        { teams: map_query }
      end

      private

      def teams_table
        Team.arel_table
      end

      def columns
        [
          teams_table[:id],
          teams_table[:name],
          teams_table[:tag],
          teams_table[:logo],
        ]
      end

      def arel_query
        teams_table
          .project(columns)
          .order(teams_table[:id])
      end

      def map_query
        execute_query.map do |row|
          {
            id: row[0],
            name: row[1],
            tag: row[2],
            logo: row[3]
          }
        end
      end
    end
  end
end
