# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersHelper, type: :helper do
  describe '#sort_link' do
    it 'builds a reversed sort key when the same sort column is active' do
      params = ActionController::Parameters.new(sort: 'name', page: 2)
      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:url_for).and_return('/users?sort=name_reverse')

      helper.sort_link('Name', 'name')

      expect(helper).to have_received(:url_for).with(params: params.merge(sort: 'name_reverse', page: nil))
    end

    it 'keeps the original sort key for a new sort column' do
      params = ActionController::Parameters.new(sort: 'created_at', page: 2)
      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:url_for).and_return('/users?sort=name')

      helper.sort_link('Name', 'name')

      expect(helper).to have_received(:url_for).with(params: params.merge(sort: 'name', page: nil))
    end
  end

  describe '#steamid_tool' do
    let(:relation) { instance_double(ActiveRecord::Relation) }

    it 'returns the data file URL when the tool exists' do
      data_file = build_stubbed(:data_file)

      allow(DataFile).to receive(:where).with("name LIKE '%SteamID Finder%'").and_return(relation)
      allow(relation).to receive(:first).and_return(data_file)

      expect(helper.steamid_tool).to eq(helper.data_file_url(data_file))
    end

    it 'falls back to the homepage when the tool is missing' do
      allow(DataFile).to receive(:where).with("name LIKE '%SteamID Finder%'").and_return(relation)
      allow(relation).to receive(:first).and_return(nil)

      expect(helper.steamid_tool).to eq('/')
    end
  end
end
