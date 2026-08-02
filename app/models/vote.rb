# frozen_string_literal: true

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

class Vote < ApplicationRecord
  include Extra

  # attr_protected :id, :updated_at, :created_at, :user_id

  validates :user_id,
            uniqueness: { scope: %i[votable_id votable_type], message: 'You have already voted for this choice' }
  validates :user_id, :votable_id, :votable_type, presence: true

  belongs_to :user, optional: true
  belongs_to :votable, polymorphic: true, optional: true

  after_create :increase_votes
  after_destroy :decrease_votes

  def increase_votes
    # rubocop:disable Rails/SkipsModelValidations
    votable.poll.class.increment_counter(:votes, votable.poll.id) if votable_type == 'Option'
    votable.class.increment_counter(:votes, votable.id)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def decrease_votes
    # rubocop:disable Rails/SkipsModelValidations
    votable.poll.class.decrement_counter(:votes, votable.poll.id) if votable_type == 'Option'
    votable.class.decrement_counter(:votes, votable.id)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def can_create?(cuser)
    return false unless cuser

    case votable_type
    when 'Option' then !votable.poll.voted?(cuser)
    when 'Gatherer', 'GatherMap', 'GatherServer' then gather_vote_allowed?(cuser)
    else true
    end
  end

  def self.params(params, _cuser)
    params.require(:vote).permit(:votable_type, :votable_id, :poll_id, :user_id)
  end

  validate :validate_gather_vote_limits, on: :create

  private

  def gather_vote_allowed?(cuser)
    return false unless votable.gather.users.exists?(cuser.id)

    case votable_type
    when 'Gatherer' then gatherer_vote_allowed?(cuser)
    when 'GatherMap' then map_vote_allowed?(cuser)
    when 'GatherServer' then server_vote_allowed?(cuser)
    end
  end

  def gatherer_vote_allowed?(cuser)
    return false unless votable.gather.status == Gather::STATE_VOTING

    votes = votable.gather.gatherer_votes
    return false if votes.where(user_id: cuser.id, votable_id: votable.id).exists?

    votes.where(user_id: cuser.id).count < 2
  end

  def map_vote_allowed?(cuser)
    return false if votable.gather.status == Gather::STATE_FINISHED

    votes = votable.gather.map_votes
    return false if votes.where(user_id: cuser.id, votable_id: votable.id).count.positive?

    votes.where(user_id: cuser.id).count < 2
  end

  def server_vote_allowed?(cuser)
    return false if votable.gather.status == Gather::STATE_FINISHED

    votes = votable.gather.server_votes
    return false if votes.where(user_id: cuser.id, votable_id: votable.id).exists?

    votes.where(user_id: cuser.id).count < 2
  end

  def validate_gather_vote_limits
    return unless %w[GatherMap GatherServer].include?(votable_type)
    return unless votable.respond_to?(:gather) && user

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
