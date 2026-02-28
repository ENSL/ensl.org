# == Schema Information
#
# Table name: votes
#
#  id           :integer          not null, primary key
#  votable_type :string(255)
#  poll_id      :integer
#  user_id      :integer
#  votable_id   :integer
#
# Indexes
#
#  index_votes_on_user_id                      (user_id)
#  index_votes_on_votable_id_and_votable_type  (votable_id,votable_type)
#

class Vote < ActiveRecord::Base
  include Extra

  # attr_protected :id, :updated_at, :created_at, :user_id

  validates :user_id,
            uniqueness: { scope: %i[votable_id votable_type], message: 'You have already voted for this choice' }
  validates_presence_of :user_id, :votable_id, :votable_type

  belongs_to :user, optional: true
  belongs_to :votable, polymorphic: true, optional: true

  after_create :increase_votes
  after_destroy :decrease_votes

  def increase_votes
    votable.poll.increment! :votes if votable_type == 'Option'
    # Use increment! for atomic update to avoid race conditions
    votable.increment! :votes
  end

  def decrease_votes
    votable.poll.decrement! :votes if votable_type == 'Option'
    # Use decrement! for atomic update to avoid race conditions
    votable.decrement! :votes
  end

  def can_create?(cuser)
    return false unless cuser

    if votable_type == 'Option'
      return false if votable.poll.voted?(cuser)
    elsif %w[Gatherer GatherMap GatherServer].include?(votable_type)
      return false unless votable.gather.users.exists? cuser.id

      case votable_type
      when 'Gatherer'
        return false if votable.gather.status != Gather::STATE_VOTING
        return false if votable.gather.gatherer_votes.where(user_id: cuser.id, votable_id: votable.id).exists?
        return false if votable.gather.gatherer_votes.where(user_id: cuser.id).count >= 2
      when 'GatherMap'
        return false if votable.gather.status == Gather::STATE_FINISHED
        # Do not let user vote for same map twice
        return false if votable.gather.map_votes.where(user_id: cuser.id, votable_id: votable.id).count > 0
        # Limit total map votes per user per gather to 2
        return false if votable.gather.map_votes.where(user_id: cuser.id).count >= 2
      when 'GatherServer'
        return false if votable.gather.status == Gather::STATE_FINISHED
        # Do not let user vote for same server twice
        return false if votable.gather.server_votes.where(user_id: cuser.id, votable_id: votable.id).exists?
        # Allow up to two server votes per user
        return false if votable.gather.server_votes.where(user_id: cuser.id).count >= 2
      end
    end

    true
  end

  def self.params(params, cuser)
    params.require(:vote).permit(:votable_type, :votable_id, :poll_id, :user_id)
  end

  validate :validate_gather_vote_limits, on: :create

  private

  def validate_gather_vote_limits
    return unless %w[GatherMap GatherServer].include?(votable_type)
    return unless votable && votable.respond_to?(:gather) && user

    if votable.gather.nil?
      errors.add(:base, 'Invalid gather')
      return
    end

    case votable_type
    when 'GatherMap'
      if votable.gather.map_votes.where(user_id: user.id).count >= 2
        errors.add(:base, 'Maximum map votes reached for this gather')
      end
    when 'GatherServer'
      if votable.gather.server_votes.where(user_id: user.id, votable_id: votable.id).exists?
        errors.add(:base, 'You have already voted for this server')
      end
      if votable.gather.server_votes.where(user_id: user.id).count >= 2
        errors.add(:base, 'Maximum server votes reached for this gather')
      end
    end
  end
end
