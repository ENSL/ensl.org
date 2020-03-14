# == Schema Information
#
# Table name: forumers
#
#  id         :integer          not null, primary key
#  forum_id   :integer
#  group_id   :integer
#  access     :integer
#  created_at :datetime
#  updated_at :datetime
#

require "rails_helper"

describe Forumer do
  describe "create" do
    let(:forumer) { build :forumer }

    it "creates a new forumer" do
      expect(forumer.valid?).to eq(true)
      expect do
        forumer.save!
      end.to change(Forumer, :count).by(1)
    end
  end
end
