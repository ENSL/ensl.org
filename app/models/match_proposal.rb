class MatchProposal < ActiveRecord::Base

  STATUS_PENDING = 0
  STATUS_REVOKED = 1
  STATUS_REJECTED = 2
  STATUS_CONFIRMED = 3

  belongs_to :match
  belongs_to :team
  has_many :confirmed_by, class_name: 'Team', uniq: true
  attr_accessible :proposed_time, :status

  validates_presence_of :match, :team, :proposed_time

  def status_strings
    {STATUS_PENDING   => 'Pending',
     STATUS_REVOKED   => 'Revoked',
     STATUS_REJECTED  => 'Rejected',
     STATUS_CONFIRMED => 'Confirmed'}
  end

  def can_create? cuser
    return false unless cuser && match
    return true if cuser.admin?
    match.can_make_proposal?(cuser)
  end

  def can_update? cuser, params = {}
    return false unless cuser && match && match.can_make_proposal?(cuser)
    return true if cuser.admin?

    if params.key?(:status) && (status !=(new_status = params[:status].to_i))
      return false if new_status == STATUS_PENDING
      case this.status
        when STATUS_REVOKED
          return false
        when STATUS_PENDING
          case new_status
            when STATUS_CONFIRMED, STATUS_REJECTED
              return false unless this.team != cuser.team
              # TODO: Use time depending on rules
              return false if (STATUS_CONFIRMED.to_s == new_status) && (proposed_time < 20.minutes.from_now)
            when STATUS_REVOKED
              return false unless (this.team == cuser.team)
            else
              return false
          end
        when STATUS_CONFIRMED, STATUS_REJECTED
          return true
        else
          return false
      end
    end

    true
  end

  def can_destroy?
    cuser && cuser.admin?
  end

end
