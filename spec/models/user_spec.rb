# == Schema Information
#
# Table name: users
#
#  id           :integer          not null, primary key
#  birthdate    :date
#  country      :string(255)
#  email        :string(255)
#  firstname    :string(255)
#  lastip       :string(255)
#  lastname     :string(255)
#  lastvisit    :datetime
#  password     :string(255)
#  public_email :boolean          default(FALSE), not null
#  steamid      :string(255)
#  time_zone    :string(255)
#  username     :string(255)
#  version      :integer
#  created_at   :datetime
#  updated_at   :datetime
#  team_id      :integer
#
# Indexes
#
#  index_users_on_lastvisit  (lastvisit)
#  index_users_on_team_id    (team_id)
#

require 'rails_helper'

describe User do
  let!(:user) { create :user }

  describe "#banned?" do
    it "returns false if user is not banned" do
      expect(user.banned?).to be_falsey
    end

    it "returns true if user is banned" do
      Ban.create!(ban_type: Ban::TYPE_SITE,
                  expiry: Time.now.utc + 10.days,
                  user_name: user.username)

      expect(user.banned?).to be_truthy
    end

    it "returns true for specific bans" do
      Ban.create!(ban_type: Ban::TYPE_MUTE,
                  expiry: Time.now.utc + 10.days,
                  user_name: user.username)

      expect(user.banned? Ban::TYPE_MUTE).to be_truthy
    end
  end

  describe "#gather_moderator?" do
    let!(:group) { create :group, :gather_moderator }

    it "returns true if gather moderator" do
      create :grouper, group: group, user: user
      expect(user.gather_moderator?).to eq(true)
    end
    it "returns false if not gather moderator" do
      expect(user.gather_moderator?).to eq(false)
    end
  end
end
