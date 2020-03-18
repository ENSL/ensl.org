# == Schema Information
#
# Table name: issues
#
#  id          :integer          not null, primary key
#  solution    :text(65535)
#  status      :integer
#  text        :text(65535)
#  text_parsed :text(65535)
#  title       :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  assigned_id :integer
#  author_id   :integer
#  category_id :integer
#
# Indexes
#
#  index_issues_on_assigned_id  (assigned_id)
#  index_issues_on_author_id    (author_id)
#  index_issues_on_category_id  (category_id)
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
