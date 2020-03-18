# == Schema Information
#
# Table name: forums
#
#  id          :integer          not null, primary key
#  description :string(255)
#  position    :integer
#  title       :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  category_id :integer
#
# Indexes
#
#  index_forums_on_category_id  (category_id)
#

require "rails_helper"

describe Forum do
  let!(:user) { create :user }

  describe "create" do
    let(:forum) { build :forum }

    it "creates a new forum" do
      expect(forum.valid?).to eq(true)
      expect do
        forum.save!
      end.to change(Forum, :count).by(1)
    end
  end
end
