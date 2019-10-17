# == Schema Information
#
# Table name: forums
#
#  id          :integer          not null, primary key
#  title       :string(255)
#  description :string(255)
#  category_id :integer
#  created_at  :datetime
#  updated_at  :datetime
#  position    :integer
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
