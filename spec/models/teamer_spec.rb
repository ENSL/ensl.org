# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teamer, type: :model do
  describe 'init_variables' do
    it 'sets default rank to RANK_JOINER' do
      t = Teamer.new
      t.send(:init_variables)
      expect(t.rank).to eq(Teamer::RANK_JOINER)
    end
  end

  describe 'validate_team' do
    it 'prevents a user joining same team twice' do
      user = create(:user)
      team = create(:team)
      create(:teamer, user: user, team: team)
      t2 = Teamer.new(user: user, team: team)
      expect(t2.valid?).to be false
      expect(t2.errors[:team]).not_to be_empty
    end
  end

  describe 'destroy behavior' do
    it 'destroys a join request without changing another valid primary team' do
      user = create(:user)
      primary_team = create(:team)
      requested_team = create(:team)
      create(:teamer, user: user, team: primary_team, rank: Teamer::RANK_MEMBER)
      user.update!(team: primary_team)
      request = create(:teamer, user: user, team: requested_team, rank: Teamer::RANK_JOINER)

      request.destroy

      expect(Teamer.where(id: request.id)).to be_empty
      expect(user.reload.team).to eq(primary_team)
    end

    it 'marks rank REMOVED for non-joiner' do
      user = create(:user)
      team = create(:team)
      t = Teamer.create!(user: user, team: team, rank: Teamer::RANK_MEMBER)
      t.destroy
      expect(t.reload.rank).to eq(Teamer::RANK_REMOVED)
    end
  end

  describe 'permissions' do
    it 'allows destroy for owner, leader, or admin' do
      owner = create(:user)
      leader = create(:user)
      admin = create(:user, :admin)
      team = create(:team)
      te = Teamer.create!(user: owner, team: team, rank: Teamer::RANK_MEMBER)
      Teamer.create!(user: leader, team: team, rank: Teamer::RANK_LEADER)

      expect(te.can_destroy?(owner)).to be true
      expect(te.can_destroy?(leader)).to be true
      expect(te.can_destroy?(admin)).to be true
    end
  end
end

RSpec.describe Teamer, type: :model do
  describe 'basic helpers' do
    it 'init_variables sets joiner rank by default' do
      t = Teamer.new
      t.init_variables
      expect(t.rank).to eq Teamer::RANK_JOINER
    end

    it 'to_s delegates to user' do
      t = build(:teamer)
      expect(t.to_s).to eq t.user.to_s
    end
  end

  describe 'validation' do
    it 'does not allow same user to join same team twice' do
      user = create(:user)
      team = create(:team)
      create(:teamer, user: user, team: team)
      t2 = Teamer.new(user: user, team: team)
      t2.validate
      expect(t2.errors[:team]).not_to be_empty
    end

    it 'allows rejoining after previous membership is removed' do
      user = create(:user)
      team = create(:team)
      create(:teamer, user: user, team: team, rank: Teamer::RANK_REMOVED)

      t2 = Teamer.new(user: user, team: team, rank: Teamer::RANK_JOINER)

      expect(t2).to be_valid
    end
  end

  describe 'destroy behavior' do
    it 'destroys when rank is joiner' do
      t = create(:teamer, rank: Teamer::RANK_JOINER)
      id = t.id
      t.destroy
      expect(Teamer.exists?(id)).to be false
    end

    it 'marks removed when rank is not joiner' do
      t = create(:teamer, rank: Teamer::RANK_MEMBER)
      t.destroy
      expect(t.reload.rank).to eq Teamer::RANK_REMOVED
    end

    it 'clears user team without running full user validations' do
      member = create(:user, username: 'MemberOne')
      duplicate = create(:user, username: 'MemberTwo')
      # Intentionally create a broken duplicate-username state without invoking the
      # model validation layer; the test is verifying that the destroy path bypasses
      # user validations while clearing team membership.
      # rubocop:disable Rails/SkipsModelValidations
      duplicate.update_columns(username: member.username.downcase)
      # rubocop:enable Rails/SkipsModelValidations

      team = create(:team)
      # This intentionally bypasses validations because the duplicate username state
      # is already present and the test is exercising the destroy path, not user save validation.
      # rubocop:disable Rails/SkipsModelValidations
      member.update_columns(team_id: team.id, updated_at: Time.current)
      # rubocop:enable Rails/SkipsModelValidations
      teamer = create(:teamer, user: member, team: team, rank: Teamer::RANK_MEMBER)

      expect { User.find(member.id).update!(team_id: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { teamer.destroy }.not_to raise_error
      expect(member.reload.team_id).to be_nil
      expect(teamer.reload.rank).to eq(Teamer::RANK_REMOVED)
    end
  end

  describe 'permissions' do
    let(:team) { create(:team) }
    let(:user) { create(:user) }

    it 'can_create? requires verification params' do
      t = Teamer.new(user: user, team: team)
      allow(Verification).to receive(:contain).and_return(true)
      expect(t.can_create?(user, user_id: user.id, team_id: team.id)).to be true
    end

    it 'allows only admins to create a membership by username' do
      teamer = Teamer.new(username: user.username, team: team)
      admin = create(:user, :admin)

      expect(teamer.can_create?(admin, username: user.username, team_id: team.id)).to be true
      expect(teamer.can_create?(user, username: user.username, team_id: team.id)).to be false
    end

    it 'can_update? requires admin' do
      t = build(:teamer)
      admin = double('User')
      allow(admin).to receive(:admin?).and_return(true)
      expect(t.can_update?(admin)).to be true
    end

    it 'can_destroy? allows owner, leader, or admin' do
      team = create(:team)
      owner = create(:user)
      t = create(:teamer, user: owner, team: team)

      expect(t.can_destroy?(owner)).to be true

      leader = create(:user)
      allow(team).to receive(:is_leader?).with(leader).and_return(true)
      expect(t.can_destroy?(leader)).to be true

      admin = double('User')
      allow(admin).to receive(:admin?).and_return(true)
      allow(team).to receive(:is_leader?).with(admin).and_return(false)
      expect(t.can_destroy?(admin)).to be true

      other = create(:user)
      allow(team).to receive(:is_leader?).with(other).and_return(false)
      allow(other).to receive(:admin?).and_return(false)
      expect(t.can_destroy?(other)).to be false
    end
  end

  describe 'username lookup' do
    let(:team) { create(:team) }

    it 'resolves an existing user before validation' do
      user = create(:user)
      teamer = Teamer.new(username: user.username, team: team, rank: Teamer::RANK_MEMBER)

      expect(teamer).to be_valid
      expect(teamer.user).to eq(user)
    end

    it 'adds an error for an unknown username' do
      teamer = Teamer.new(username: 'missing-user', team: team, rank: Teamer::RANK_MEMBER)

      expect(teamer).not_to be_valid
      expect(teamer.errors[:username]).to include('User not found')
    end
  end

  describe '#submit_for_actor' do
    it 'assigns actor to non-admin applications and removes previous join application on success' do
      actor = create(:user)
      old_team = create(:team)
      new_team = create(:team)
      old_application = create(:teamer, user: actor, team: old_team, rank: Teamer::RANK_JOINER)
      teamer = build(:teamer, user: nil, team: new_team, rank: Teamer::RANK_JOINER)

      result = teamer.submit_for_actor(actor)

      expect(result).to be true
      expect(teamer.user).to eq(actor)
      expect(teamer).to be_persisted
      expect(Teamer.exists?(old_application.id)).to be false
    end

    it 'does not override the teamer user when actor is admin' do
      actor = create(:user, :admin)
      owner = create(:user)
      teamer = build(:teamer, user: owner, team: create(:team), rank: Teamer::RANK_JOINER)

      result = teamer.submit_for_actor(actor)

      expect(result).to be true
      expect(teamer.user).to eq(owner)
    end

    it 'returns false when save fails' do
      actor = create(:user)
      teamer = build(:teamer, user: nil, team: nil)

      expect(teamer.submit_for_actor(actor)).to be false
    end
  end
end
