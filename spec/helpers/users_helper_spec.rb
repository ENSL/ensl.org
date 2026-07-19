# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersHelper, type: :helper do
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
