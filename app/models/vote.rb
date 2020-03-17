# == Schema Information
#
# Table name: votes
#
#  id           :integer          not null, primary key
#  user_id      :integer
#  votable_id   :integer
#  poll_id      :integer
#  votable_type :string(255)
#

class Vote < ActiveRecord::Base
  include Extra

  #attr_protected :id, :updated_at, :created_at, :user_id

  validates_uniqueness_of :user_id, :scope => :votable_id
  validates_presence_of :user_id, :votable_id, :votable_type

  belongs_to :user
  belongs_to :votable, :polymorphic => true

  after_create :increase_votes
  after_destroy :decrease_votes

  def increase_votes
    if votable_type == "Option"
      votable.poll.increment :votes
      votable.poll.save
    end
    votable.increment :votes
    votable.save
  end

  def decrease_votes
    if votable_type == "Option"
      votable.poll.decrement :votes
      votable.poll.save
    end
    votable.decrement :votes
    votable.save
  end

  def can_create? cuser
    return false unless cuser
    if votable_type == "Option"
      if votable.poll.voted?(cuser)
        return false
      end
    elsif votable_type == "Gatherer" or votable_type == "GatherMap" or votable_type == "GatherServer"
      return false unless votable.gather.users.exists? cuser.id

      case votable_type
      when "Gatherer" then
        return false if votable.gather.status != Gather::STATE_VOTING
        return false if votable.gather.gatherer_votes.where(user_id: user.id).count > 1
      when "GatherMap" then
        return false if votable.gather.status == Gather::STATE_FINISHED
        return false if votable.gather.map_votes.where(user_id: user.id).count > 1
      when "GatherServer" then
        return false if votable.gather.status == Gather::STATE_FINISHED
        return false if votable.gather.server_votes.where(user_id: user.id).count > 0
      end
    end

    return true
  end
end
