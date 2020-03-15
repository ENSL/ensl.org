require 'rails_helper'

RSpec.describe AboutController, type: :controller do
    it "renders the staff template" do
        get :staff
        expect(response).to render_template("staff")
    end

    context 'as an admin' do
        let!(:admin) { create(:user, :admin) }

        before do
            login_admin
        end

        it "renders the adminpanel template" do
            get :adminpanel
            expect(response).to render_template("adminpanel")
        end

        it "renders the statistics template" do
            get :statistics
            expect(response).to render_template("statistics")
        end
    end
end
