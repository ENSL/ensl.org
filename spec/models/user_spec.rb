# == Schema Information
#
# Table name: users
#
#  id           :integer          not null, primary key
#  username     :string(255)
#  password     :string(255)
#  firstname    :string(255)
#  lastname     :string(255)
#  email        :string(255)
#  steamid      :string(255)
#  team_id      :integer
#  lastvisit    :datetime
#  created_at   :datetime
#  updated_at   :datetime
#  lastip       :string(255)
#  country      :string(255)
#  birthdate    :date
#  time_zone    :string(255)
#  version      :integer
#  public_email :boolean          default(FALSE), not null
#

require 'spec_helper'

describe User do
  let!(:user) { create :user }

  describe "#banned?" do
    it "returns false if user is not banned" do
      expect(user.banned?).to be_falsey
    end

    it "returns true if user is banned" do
      Ban.create!(ban_type: Ban::TYPE_SITE,
                  expiry: Time.now + 10.days,
                  user_name: user.username)

      expect(user.banned?).to be_truthy
    end

    it "returns true for specific bans" do
      Ban.create!(ban_type: Ban::TYPE_MUTE,
                  expiry: Time.now + 10.days,
                  user_name: user.username)

      expect(user.banned? Ban::TYPE_MUTE).to be_truthy
    end
  end
end
