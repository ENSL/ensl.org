class Api::V1::UsersCollection < Api::V1::Collection
  def self.as_json
    self.new.data.to_json
  end

  def data
    { users: map_query }
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
      teams_table[:logo]
    ]
  end

  def arel_query
    users_table
    .project(columns)
    .join(teams_table, Arel::Nodes::OuterJoin)
    .on(joins)
    .where(users_table[:team_id].not_eq(nil))
    .order(users_table[:id])
  end

  def map_query
    execute_query.map do |row|
      {
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
