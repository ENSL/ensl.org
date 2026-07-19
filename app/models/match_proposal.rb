# frozen_string_literal: true

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
class MatchProposal < ApplicationRecord
  STATUS_PENDING   = 0
  STATUS_REVOKED   = 1
  STATUS_REJECTED  = 2
  STATUS_CONFIRMED = 3
  STATUS_DELAYED   = 4

  # latest time before a match to be confirmed/rejected (in minutes)
  CONFIRMATION_LIMIT = 30

  belongs_to :match, optional: true
  belongs_to :team, optional: true
  # has_many :confirmed_by, class_name: 'Team', uniq: true
  # FIXME: attr_accessible :proposed_time, :status

  validates :match, :team, :proposed_time, presence: true

  attr_accessor :actor

  after_create :notify_new_proposal
  after_update :notify_status_change, if: :saved_change_to_status?

  scope :confirmed_for_match, ->(match) { where('match_id = ? AND status = ?', match.id, STATUS_CONFIRMED) }
  scope :confirmed_for_contest, lambda { |contest|
    includes(:match).where(matches: { contest_id: contest.id }, status: STATUS_CONFIRMED)
  }

  def self.status_strings
    { STATUS_PENDING => 'Pending',
      STATUS_REVOKED => 'Revoked',
      STATUS_REJECTED => 'Rejected',
      STATUS_CONFIRMED => 'Confirmed',
      STATUS_DELAYED => 'Delayed' }
  end

  def status_name
    self.class.status_strings[status]
  end

  def can_create?(cuser)
    return false unless cuser && match
    return true if cuser.admin?

    match.can_make_proposal?(cuser)
  end

  def can_update?(cuser, params = {})
    return false unless cuser && match && (cuser.admin? || match.can_make_proposal?(cuser))

    if params.key?(:status) && (status != (new_status = params[:status].to_i))
      return status_change_allowed?(cuser, new_status)
    end

    true
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def state_immutable?
    [STATUS_REJECTED, STATUS_DELAYED, STATUS_REVOKED].include?(status)
  end

  def status_change_allowed?(cuser, new_status)
    case new_status
    when STATUS_PENDING
      # never go back to pending
      false
    when STATUS_DELAYED
      # only confirmed matches can be set to delayed
      # only admins can set matches to delayed and only if they are not playing in that match
      # matches can only be delayed if they are not to far in the future
      status == STATUS_CONFIRMED && cuser.admin? &&
        !match.user_in_match?(cuser) && proposed_time <= CONFIRMATION_LIMIT.minutes.from_now
    when STATUS_REVOKED
      # unconfirmed can only be revoked by team making the proposal
      # confirmed can only be revoked if soon enough before match time
      status == STATUS_PENDING && team == cuser.team ||
        status == STATUS_CONFIRMED && proposed_time > CONFIRMATION_LIMIT.minutes.from_now
    when STATUS_CONFIRMED, STATUS_REJECTED
      # only team proposed to can reject or confirm and only if soon enough before match time
      status_ok = status == STATUS_PENDING
      team_ok = team != cuser.team
      time_ok = CONFIRMATION_LIMIT.minutes.from_now < proposed_time

      status_ok && team_ok && time_ok
    else
      # invalid status
      false
    end
  end

  def self.params(params, _cuser)
    params.require(:match_proposal).permit(:status, :match_id, :team_id, :proposed_time)
  end

  private

  def notify_new_proposal
    return unless actor

    send_team_message('New Scheduling Proposal', new_proposal_message)
  end

  def notify_status_change
    return unless actor

    send_team_message('Scheduling Proposal Update', status_change_message)
  end

  def send_team_message(title, text)
    return unless text

    Message.create(
      sender_type: 'System',
      recipient_type: 'Team',
      title: title,
      recipient: match.get_opposing_team(actor.team),
      text: text
    )
  end

  def new_proposal_message
    "There is a new scheduling proposal for your match against #{actor.team.name}.\n" \
      "Find it [url=#{proposals_path}]here[/url]"
  end

  def status_change_message
    case status
    when STATUS_CONFIRMED
      "A scheduling proposal for your match against [b]#{actor.team.name}[/b] was confirmed!.\n" \
        "Find it [url=#{proposals_path}]here[/url]"
    when STATUS_REJECTED
      "A scheduling proposal for your match against [b]#{actor.team.name}[/b] was rejected!.\n" \
        "Find it [url=#{proposals_path}]here[/url]"
    when STATUS_REVOKED
      "A scheduling proposal for your match against [b]#{actor.team.name}[/b] was revoked!.\n" \
        "Find it [url=#{proposals_path}]here[/url]"
    when STATUS_DELAYED
      "Delaying for your match against [b]#{actor.team.name}[/b] was permitted!.\n" \
        "Schedule a new time as soon as possible [url=#{proposals_path}]here[/url]"
    end
  end

  def proposals_path
    Rails.application.routes.url_helpers.match_proposals_path(match)
  end
end
