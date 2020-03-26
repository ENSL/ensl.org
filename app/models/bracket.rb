# == Schema Information
#
# Table name: brackets
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  slots      :integer
#  created_at :datetime
#  updated_at :datetime
#  contest_id :integer
#
# Indexes
#
#  index_brackets_on_contest_id  (contest_id)
#

class Bracket < ActiveRecord::Base
  include Extra

  #attr_protected :id, :created_at, :updated_at

  belongs_to :contest, :optional => true
  has_many :bracketers

  def to_s
    "#" + self.id.to_s
  end

  def get_bracketer row, col
    b = bracketers.pos(row, col).first
    unless b
      b = bracketers.build
      b.row = row.to_i
      b.column = col.to_i
      b.save
    end
    return b
  end

  def options
    ["-- Matches"] \
      + contest.matches.collect{|c| [c, "match_#{c.id}"]} \
      + ["-- Teams"] \
      + contest.contesters.collect{|c| [c, "contester_#{c.id}"]}
  end

  def default row, col
    if b = bracketers.pos(row, col).first
      if b.match
        return "match_#{b.match_id}"
      elsif b.contester
        return "contester_#{b.team_id}"
      end
    end
  end

  def update_cells params
    params.each do |row, cols|
      cols.each do |col, val|
        unless val.include? "--"
          b = get_bracketer(row, col)
          if m = val.match(/match_(\d*)/)
            b.update_attribute :match_id, m[1].to_i
            b.update_attribute :team_id, nil
          elsif m = val.match(/contester_(\d*)/)
            b.update_attribute :team_id, m[1].to_i
            b.update_attribute :match_id, nil
          end
        end
      end
    end
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.params params, cuser
    params.require(:bracket).permit(:contest_id, :slots, :name)
  end
end
