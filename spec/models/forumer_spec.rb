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

require "spec_helper"

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
