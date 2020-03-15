# == Schema Information
#
# Table name: issues
#
#  id          :integer          not null, primary key
#  title       :string(255)
#  status      :integer
#  assigned_id :integer
#  category_id :integer
#  text        :text
#  author_id   :integer
#  created_at  :datetime
#  updated_at  :datetime
#  solution    :text
#  text_parsed :text
#

require "rails_helper"
require 'pry'

describe "User" do
  describe "Permissions" do
    let!(:user) { create :user }
    let!(:admin) { create :user, :admin }
    let(:issue) { Issue.new }

    describe "can_show?" do
      it "returns true for author" do
        issue.author = user
        expect(issue.can_show? user).to be_truthy
      end

      it "returns true for admin" do
        expect(issue.can_show? admin).to be_truthy
      end

      it "returns false if neither admin nor author" do
        expect(issue.can_show? user).to be_falsey
      end
    end

    describe "can_create?" do
      it "returns true" do
        expect(issue.can_create? nil).to be_truthy
      end
    end

    describe "can_update?" do
      it "returns true for admin" do
        expect(issue.can_update? admin).to be_truthy
      end

      it "returns false for non-admin" do
        expect(issue.can_update? user).to be_falsey
      end
    end

    describe "can_destroy?" do
      it "returns true for admin" do
        expect(issue.can_destroy? admin).to be_truthy
      end

      it "returns false for non-admin" do
        expect(issue.can_destroy? user).to be_falsey
      end
    end
  end
end
