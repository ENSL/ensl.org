class ChangeImages < ActiveRecord::Migration
  def up
    Profile.transaction do
      Profile.where("avatar IS NOT NULL").each do |p|
        Profile.update_all(["avatar = ?", "#{p.id}#{File.extname(p.avatar.to_s)}"], "id = #{p.id}") if p.avatar and p.avatar.to_s
      end
    end
    Movie.transaction do
      Movie.where("picture IS NOT NULL").each do |p|
        Movie.update_all(["picture = ?", "#{p.id}#{File.extname(p.picture.to_s)}"], "id = #{p.id}") if p.picture and p.picture.to_s
      end
    end
    Team.transaction do
      Team.where("logo IS NOT NULL").each do |p|
        Team.update_all(["logo = ?", "#{p.id}#{File.extname(p.logo.to_s)}"], "id = #{p.id}") if p.logo and p.logo.to_s
      end
    end
  end

  def down
  end
end
