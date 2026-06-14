require 'rails_helper'

RSpec.describe Profile, type: :model do
  describe '#init_steam_profile' do
    it 'extracts numeric ids from profile URLs' do
      profile = build(:profile, steam_profile: 'http://steamcommunity.com/profiles/76561198000000000')

      profile.valid?

      expect(profile.steam_profile).to eq('76561198000000000')
    end

    it 'extracts vanity ids from vanity URLs' do
      profile = build(:profile, steam_profile: 'http://steamcommunity.com/id/test-user_42')

      profile.valid?

      expect(profile.steam_profile).to eq('test-user_42')
    end

    it 'leaves direct steam profile values unchanged' do
      profile = build(:profile, steam_profile: 'DirectName')

      profile.valid?

      expect(profile.steam_profile).to eq('DirectName')
    end

    it 'returns early when steam_profile is blank' do
      profile = build(:profile, steam_profile: nil)

      expect { profile.valid? }.not_to change(profile, :steam_profile)
    end
  end

  describe '#parse_text' do
    it 'parses achievements and signature when present' do
      profile = build(:profile, achievements: '[b]wins[/b]', signature: '[i]sig[/i]')

      allow(profile).to receive(:bbcode_to_html).with('[b]wins[/b]').and_return('<strong>wins</strong>')
      allow(profile).to receive(:bbcode_to_html).with('[i]sig[/i]').and_return('<em>sig</em>')

      profile.save!

      expect(profile.achievements_parsed).to eq('<strong>wins</strong>')
      expect(profile.signature_parsed).to eq('<em>sig</em>')
    end
  end

  describe 'validations' do
    it 'rejects invalid msn values' do
      profile = build(:profile, msn: 'not-an-email')

      expect(profile).not_to be_valid
      expect(profile.errors[:msn]).to be_present
    end

    it 'rejects invalid icq values' do
      profile = build(:profile, icq: 'abc123')

      expect(profile).not_to be_valid
      expect(profile.errors[:icq]).to be_present
    end
  end
end
