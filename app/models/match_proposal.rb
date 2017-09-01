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
  attr_accessible :proposed_time, :status

  validates_presence_of :match, :team, :proposed_time

  scope :of_match, ->(match) { where('match_id = ?', match.id) }
  scope :confirmed_for_match, ->(match) { where('match_id = ? AND status = ?', match.id, STATUS_CONFIRMED) }
  scope :confirmed_upcoming, ->{ where('status = ? AND proposed_time > UTC_TIMESTAMP()', STATUS_CONFIRMED) }

  def status_strings
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

  private

  def status_change_allowed?(cuser, new_status)
    case new_status
      when STATUS_PENDING
        # never go back to pending
        return false
      when STATUS_DELAYED
        # only confirmed matches can be set to delayed
        # only admins can set matches to delayed and only if they are not playing in that match
        # matches can only be delayed if they are not to far in the future
        return false unless self.status == STATUS_CONFIRMED && cuser.admin? &&
            !self.match.user_in_match?(cuser) && self.proposed_time <= CONFIRMATION_LIMIT.minutes.from_now
      when STATUS_REVOKED
        # unconfirmed can only be revoked by team making the proposal
        # confirmed can only be revoked if soon enough before match time
        return false unless self.status == STATUS_PENDING && self.team == cuser.team ||
            self.status == STATUS_CONFIRMED && self.proposed_time > CONFIRMATION_LIMIT.minutes.from_now
      when STATUS_CONFIRMED, STATUS_REJECTED
        # only team proposed to can reject or confirm and only if soon enough before match time
        return false unless self.status == STATUS_PENDING && self.team != cuser.team &&
            self.proposed_time < CONFIRMATION_LIMIT.minutes.from_now
      else
        # invalid status
        return false
    end
  end

end
