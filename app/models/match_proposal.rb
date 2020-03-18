# == Schema Information
#
# Table name: match_proposals
#
#  id            :integer          not null, primary key
#  proposed_time :datetime
#  status        :integer
#  match_id      :integer
#  team_id       :integer
#
# Indexes
#
#  index_match_proposals_on_status  (status)
#
class MatchProposal < ActiveRecord::Base

  STATUS_PENDING   = 0
  STATUS_REVOKED   = 1
  STATUS_REJECTED  = 2
  STATUS_CONFIRMED = 3
  STATUS_DELAYED   = 4

  # latest time before a match to be confirmed/rejected (in minutes)
  CONFIRMATION_LIMIT = 30

  belongs_to :match
  belongs_to :team
  #has_many :confirmed_by, class_name: 'Team', uniq: true
  # FIXME: attr_accessible :proposed_time, :status

  validates_presence_of :match, :team, :proposed_time

  scope :of_match, ->(match) { where('match_id = ?', match.id) }
  scope :confirmed_for_match, ->(match) { where('match_id = ? AND status = ?', match.id, STATUS_CONFIRMED) }
  scope :confirmed_upcoming, ->{ where('status = ? AND proposed_time > UTC_TIMESTAMP()', STATUS_CONFIRMED) }
  scope :confirmed_for_contest,
        ->(contest){ includes(:match).where(matches:{contest_id: contest.id}, status: STATUS_CONFIRMED).all}

  def self.status_strings
    {STATUS_PENDING   => 'Pending',
     STATUS_REVOKED   => 'Revoked',
     STATUS_REJECTED  => 'Rejected',
     STATUS_CONFIRMED => 'Confirmed',
     STATUS_DELAYED   => 'Delayed'}
  end

  def can_create? cuser
    return false unless cuser && match
    return true if cuser.admin?
    match.can_make_proposal?(cuser)
  end

  def can_update? cuser, params = {}
    return false unless cuser && match && (cuser.admin? || match.can_make_proposal?(cuser))

    if params.key?(:status) && (self.status !=(new_status = params[:status].to_i))
      return status_change_allowed?(cuser,new_status)
    end
    true
  end

  def can_destroy?
    cuser && cuser.admin?
  end

  def state_immutable?
    status == STATUS_REJECTED ||
      status == STATUS_DELAYED ||
      status == STATUS_REVOKED
  end

  def status_change_allowed?(cuser, new_status)
    case new_status
      when STATUS_PENDING
        # never go back to pending
        return false
      when STATUS_DELAYED
        # only confirmed matches can be set to delayed
        # only admins can set matches to delayed and only if they are not playing in that match
        # matches can only be delayed if they are not to far in the future
        return self.status == STATUS_CONFIRMED && cuser.admin? &&
            !self.match.user_in_match?(cuser) && self.proposed_time <= CONFIRMATION_LIMIT.minutes.from_now
      when STATUS_REVOKED
        # unconfirmed can only be revoked by team making the proposal
        # confirmed can only be revoked if soon enough before match time
        return self.status == STATUS_PENDING && self.team == cuser.team ||
            self.status == STATUS_CONFIRMED && self.proposed_time > CONFIRMATION_LIMIT.minutes.from_now
      when STATUS_CONFIRMED, STATUS_REJECTED
        # only team proposed to can reject or confirm and only if soon enough before match time
        status_ok = self.status == STATUS_PENDING
        team_ok = self.team != cuser.team
        time_ok = CONFIRMATION_LIMIT.minutes.from_now < self.proposed_time

        return status_ok && team_ok && time_ok
      else
        # invalid status
        return false
    end
  end

  def self.params(params, cuser)
    params.require(:match_proposal).permit(:status, :match_id, :team_id, :proposed_time)
  end
end
