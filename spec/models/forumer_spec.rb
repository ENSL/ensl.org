# == Schema Information
#
# Table name: forumers
#
#  id         :integer          not null, primary key
#  access     :integer
#  created_at :datetime
#  updated_at :datetime
#  forum_id   :integer
#  group_id   :integer
#
# Indexes
#
#  index_forumers_on_forum_id  (forum_id)
#  index_forumers_on_group_id  (group_id)
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
