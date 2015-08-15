# == Schema Information
#
# Table name: bans
#
#  id         :integer          not null, primary key
#  steamid    :string(255)
#  user_id    :integer
#  addr       :string(255)
#  server_id  :integer
#  expiry     :datetime
#  reason     :string(255)
#  created_at :datetime
#  updated_at :datetime
#  ban_type   :integer
#  ip         :string(255)
#

require "spec_helper"

describe Ban do
  let!(:user) { create :user }
  let(:ban) { Ban.new }
  let!(:server) { create :server }

  describe "#check_user" do
    it "assigns user by user_name" do
      ban.user_name = user.username
      ban.check_user

      expect(ban.user).to eq(user)
    end

    it "assigns user and server if user_name not present" do
      ban.steamid = user.steamid
      ban.addr = server.addr
      ban.check_user

      expect(ban.user).to eq(user)
      expect(ban.server).to eq(server)
    end
  end

  describe "Permissions" do
    let!(:user) { create :user }
    let!(:admin) { create :user, :admin }
    let!(:server_user) { create :user }
    let(:ban) { Ban.new }

    describe "can_create?" do
      it "returns true for admins" do
        expect(ban.can_create? admin).to be_truthy
      end

      it "returns false for non-admins" do
        expect(ban.can_create? user).to be_falsey
      end
    end

    describe "can_destroy?" do
      it "returns true for admin" do
        expect(ban.can_destroy? admin).to be_truthy
      end

      it "returns false for non-admins" do
        expect(ban.can_destroy? user).to be_falsey
      end
    end

    describe "can_update?" do
      it "returns true for admin" do
        expect(ban.can_update? admin).to be_truthy
      end

      it "returns false for non-admins" do
        expect(ban.can_update? user).to be_falsey
      end
    end
  end
end
