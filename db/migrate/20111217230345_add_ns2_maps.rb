class AddNs2Maps < ActiveRecord::Migration
  def up
    Gather.all.each do |g|
      g.update_attribute :category_id, 44
    end
    change_table :servers do |s|
      s.references :category
    end
    Server.all.each do |s|
      s.update_attribute :category_id, 44
    end
    change_table :maps do |m|
      m.references :category
    end
    Map.all.each do |s|
      s.update_attribute :category_id, 44
    end
  end

  def down
    change_table :servers do |s|
      s.remove :category_id
    end
    change_table :maps do |s|
      s.remove :category_id
    end
  end
end
