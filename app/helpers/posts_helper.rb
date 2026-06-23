# frozen_string_literal: true

module PostsHelper
  def post_primary_group_entry(user)
    return nil unless user

    groupers = user.groupers
    return nil unless groupers.exists?

    target_group_id = if user.admin?
                        Group::ADMINS
                      elsif user.staff?
                        Group::STAFF
                      elsif user.caster?
                        Group::CASTERS
                      elsif user.ref?
                        Group::REFEREES
                      else
                        groupers.first&.group_id
                      end

    return nil unless target_group_id

    grouper = groupers.find_by(group_id: target_group_id) || groupers.first
    return nil unless grouper

    group = Group.find_by(id: grouper.group_id)
    return nil unless group

    [group, grouper.task]
  end
end
