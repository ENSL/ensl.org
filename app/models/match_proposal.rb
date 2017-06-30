class MatchProposal < ActiveRecord::Base

  STATUS_PENDING = 0
  STATUS_REVOKED = 1
  STATUS_REJECTED = 2
  STATUS_CONFIRMED = 3

  belongs_to :match
  belongs_to :team
  attr_accessible :proposed_time, :status

  validates_presence_of :match, :team, :proposed_time

  def status_strings
    {STATUS_PENDING   => 'Pending',
     STATUS_REVOKED   => 'Revoked',
     STATUS_REJECTED  => 'Rejected',
     STATUS_CONFIRMED => 'Confirmed'}
  end

  def can_create? cuser
    cuser && match && match.can_make_proposal?(cuser)
  end

  def can_update? cuser, params = {}
    return false unless cuser && match && match.can_make_proposal?(cuser)

    if params.key?(:status) && (status.to_s != params[:status]) &&
        (STATUS_REVOKED.to_s != params[:status])
      return false unless (team != cuser.team)
      return false if (STATUS_CONFIRMED.to_s == params[:status]) && (proposed_time < 20.minutes.from_now)
      # TODO: update to usefull timelimit
      # TODO: define rules for revoking; timelimit, access
    end
    true
  end

  def can_destroy?
    cuser && cuser.admin?
  end

end
