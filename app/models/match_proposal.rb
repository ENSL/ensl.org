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
    cuser && cuser.team.is_leader?(cuser) && match.of_team(cuser.team)
  end

  def can_update? cuser
    cuser && cuser.team.is_leader?(cuser) && match.of_team (cuser.team)
  end

  def can_destroy?
    cuser && cuser.admin?
  end

end
