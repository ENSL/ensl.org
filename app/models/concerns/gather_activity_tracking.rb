# frozen_string_literal: true

module GatherActivityTracking
  extend ActiveSupport::Concern

  included do
    include PublicActivity::Common

    has_many :activities, as: :trackable, class_name: 'PublicActivity::Activity', dependent: :destroy
  end

  def record_voting_started_activity
    create_gather_activity key: 'gather.voting_started', parameters: { player_count: gatherers.count }
  end

  def record_picking_started_activity
    create_gather_activity(
      key: 'gather.picking_started',
      parameters: {
        captain1: captain1.to_s,
        captain2: captain2.to_s,
        maps: [map1, map2].compact.map(&:to_s),
        server: server&.to_s
      }
    )
  end

  def record_finished_activity
    create_gather_activity key: 'gather.finished'
  end

  def record_admin_update_activity(actor, attributes)
    changes = saved_changes.slice(*attributes.map(&:to_s)).map do |attribute, values|
      "#{attribute.humanize}: #{activity_value(attribute, values.first)} -> #{activity_value(attribute, values.last)}"
    end
    create_gather_activity key: 'gather.admin_updated', owner: actor, parameters: { changes: changes }
  end

  def create_gather_activity(...)
    activity = create_activity(...)
    ActiveRecord.after_all_transactions_commit { Gathers::ActivityBroadcaster.call(activity) }
    activity
  end

  private

  def activity_value(attribute, value)
    return 'none' if value.nil?

    record = case attribute.to_sym
             when :captain1_id, :captain2_id then Gatherer.find_by(id: value)
             when :map1_id, :map2_id then GatherMap.find_by(id: value)
             when :server_id then Server.find_by(id: value)
             end
    return record.to_s if record
    return states[value.to_i] || value if attribute.to_sym == :status

    value
  end
end
