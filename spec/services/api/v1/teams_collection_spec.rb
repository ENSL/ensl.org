require "spec_helper"

describe Api::V1::TeamsCollection do
  let(:collection) { Api::V1::TeamsCollection.new }

  describe "#execute_query" do
    describe "when there are no teams" do
      it "returns 0 results" do
        expect(collection.execute_query.size).to eq(0)
      end
    end

    describe "when there are some teams" do
      before do
        3.times { create(:user_with_team) }
      end

      it "returns 3 results" do
        expect(collection.execute_query.size).to eq(3)
      end

      it "returns 4 columns" do
        expect(collection.execute_query.first.size).to eq(4)
      end
    end
  end
end
