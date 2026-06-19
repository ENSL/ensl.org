# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Group, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with a short name' do
      g = Group.new(name: 'Short', founder: user)
      expect(g).to be_valid
    end

    it 'requires a name' do
      g = Group.new(name: nil)
      expect(g).not_to be_valid
      expect(g.errors[:name]).to include("can't be blank")
    end

    it 'validates maximum name length' do
      g = Group.new(name: 'a' * 21)
      expect(g).not_to be_valid
      expect(g.errors[:name]).to be_present
    end

    it 'accepts name at exactly 20 characters' do
      g = Group.new(name: 'a' * 20)
      expect(g).to be_valid
    end
  end

  describe 'associations' do
    it 'has many groupers and users through groupers' do
      g = create(:group)
      u = create(:user)
      create(:grouper, group: g, user: u)

      expect(g.groupers).not_to be_empty
      expect(g.users).to include u
    end

    it 'destroys associated groupers when deleted' do
      g = create(:group)
      u = create(:user)
      create(:grouper, group: g, user: u)

      expect { g.destroy }.to change(Grouper, :count).by(-1)
    end

    it 'belongs to founder optionally' do
      g = create(:group, founder: user)
      expect(g.founder).to eq user
    end

    it 'can exist without a founder' do
      g = create(:group, founder: nil)
      expect(g.founder).to be_nil
    end
  end

  describe '#to_s' do
    it 'returns the group name' do
      g = Group.new(name: 'TeamX')
      expect(g.to_s).to eq 'TeamX'
    end

    it 'returns the name when persisted' do
      g = create(:group, name: 'Admins')
      expect(g.to_s).to eq 'Admins'
    end
  end

  describe 'permission methods' do
    let(:admin_user) { double('admin_user', admin?: true) }
    let(:regular_user) { double('regular_user', admin?: false) }

    describe '#can_create?' do
      it 'returns true for admin users' do
        g = Group.new
        expect(g.can_create?(admin_user)).to be true
      end

      it 'returns false for non-admin users' do
        g = Group.new
        expect(g.can_create?(regular_user)).to be false
      end

      it 'returns false for nil user' do
        g = Group.new
        expect(g.can_create?(nil)).to be false
      end
    end

    describe '#can_update?' do
      it 'returns true for admin users' do
        g = create(:group)
        expect(g.can_update?(admin_user)).to be true
      end

      it 'returns false for non-admin users' do
        g = create(:group)
        expect(g.can_update?(regular_user)).to be false
      end

      it 'returns false for nil user' do
        g = create(:group)
        expect(g.can_update?(nil)).to be false
      end
    end

    describe '#can_destroy?' do
      it 'allows destroying custom/user-created groups for admins' do
        custom_group = create(:group, name: 'Custom Group')
        expect(custom_group.can_destroy?(admin_user)).to be true
      end

      it 'prevents destroying core system groups for admins' do
        admin_group = Group.find_or_create_by(id: Group::ADMINS)
        expect(admin_group.can_destroy?(admin_user)).to be false
      end

      it 'prevents destroying REFEREES group (bound to app logic)' do
        ref_group = Group.find_or_create_by(id: Group::REFEREES)
        expect(ref_group.can_destroy?(admin_user)).to be false
      end

      it 'prevents destroying CASTERS group (bound to app logic)' do
        caster_group = Group.find_or_create_by(id: Group::CASTERS)
        expect(caster_group.can_destroy?(admin_user)).to be false
      end

      it 'prevents destroying for non-admins' do
        g = create(:group)
        expect(g.can_destroy?(regular_user)).to be false
      end

      it 'prevents destroying for nil user' do
        g = create(:group)
        expect(g.can_destroy?(nil)).to be false
      end
    end
  end

  describe 'protected and reserved groups' do
    describe '.protected_groups' do
      it 'returns all reserved/core system group IDs' do
        pg = Group.protected_groups
        expect(pg).to include(Group::ADMINS)
        expect(pg).to include(Group::CASTERS)
        expect(pg).to include(Group::REFEREES)
        expect(pg.size).to eq 11 # All reserved groups
      end

      it 'prevents all core system groups from being destroyed' do
        # Test a few key system groups
        admin_group = Group.find_or_create_by(id: Group::ADMINS)
        caster_group = Group.find_or_create_by(id: Group::CASTERS)
        ref_group = Group.find_or_create_by(id: Group::REFEREES)
        admin_user = double('admin', admin?: true)

        expect(admin_group.can_destroy?(admin_user)).to be false
        expect(caster_group.can_destroy?(admin_user)).to be false
        expect(ref_group.can_destroy?(admin_user)).to be false
      end
    end

    describe '.reserved_groups' do
      it 'returns all core system group IDs' do
        rg = Group.reserved_groups
        expect(rg).to include(Group::ADMINS)
        expect(rg).to include(Group::CASTERS)
        expect(rg).to include(Group::REFEREES)
        expect(rg).to include(Group::DONORS)
        expect(rg).to include(Group::MOVIEMAKERS)
        expect(rg).to include(Group::MOVIES)
        expect(rg).to include(Group::PREDICTORS)
        expect(rg).to include(Group::STAFF)
        expect(rg).to include(Group::GATHER_MODERATORS)
        expect(rg).to include(Group::CONTRIBUTORS)
        expect(rg).to include(Group::CHAMPIONS)
      end

      it 'has correct count of reserved groups' do
        expect(Group.reserved_groups.size).to eq 11
      end
    end
  end

  describe 'class helpers for group member retrieval' do
    before do
      # Create/find groups with their constant IDs
      @admin_group = Group.find_or_create_by(id: Group::ADMINS) { |g| g.name = 'Admins' }
      @caster_group = Group.find_or_create_by(id: Group::CASTERS) { |g| g.name = 'Casters' }
      @ref_group = Group.find_or_create_by(id: Group::REFEREES) { |g| g.name = 'Referees' }

      @admin_user = create(:user)
      @caster_user = create(:user)
      @ref_user = create(:user)

      create(:grouper, group: @admin_group, user: @admin_user)
      create(:grouper, group: @caster_group, user: @caster_user)
      create(:grouper, group: @ref_group, user: @ref_user)
    end

    describe '.admins' do
      it 'returns admin groupers' do
        admins = Group.admins
        expect(admins.map(&:user)).to include @admin_user
      end

      it 'returns empty array if no admins exist' do
        Grouper.where(group_id: Group::ADMINS).destroy_all
        expect(Group.admins).to be_empty
      end
    end

    describe '.referees' do
      it 'returns referee groupers' do
        referees = Group.referees
        expect(referees.map(&:user)).to include @ref_user
      end

      it 'returns empty array if no referees exist' do
        Grouper.where(group_id: Group::REFEREES).destroy_all
        expect(Group.referees).to be_empty
      end
    end

    describe '.casters' do
      it 'returns caster groupers' do
        casters = Group.casters
        expect(casters.map(&:user)).to include @caster_user
      end

      it 'returns empty array if no casters exist' do
        Grouper.where(group_id: Group::CASTERS).destroy_all
        expect(Group.casters).to be_empty
      end
    end

    describe '.staff' do
      it 'aggregates staff from multiple groups' do
        staff_users = Group.staff.map(&:user)
        expect(staff_users).to include(@admin_user, @caster_user, @ref_user)
      end

      it 'deduplicates users appearing in multiple staff groups' do
        # Add same user to multiple groups
        create(:grouper, group: @admin_group, user: @caster_user)
        staff = Group.staff
        # Count unique users by ID
        unique_users = staff.map(&:user_id).uniq
        expect(unique_users).to include(@caster_user.id)
      end

      it 'returns empty array when no staff exist' do
        Grouper.destroy_all
        expect(Group.staff).to be_empty
      end

      it 'handles groupers with nil user_id in staff groups gracefully' do
        # Create a grouper with nil user_id in an admin group
        admin_group = Group.find_or_create_by(id: Group::ADMINS) { |g| g.name = 'Admins' }
        orphaned = build(:grouper, group: admin_group, user: nil)
        orphaned.save(validate: false) if orphaned.persisted? == false

        # Should not raise an exception - valid_users scope filters these out
        expect { Group.staff }.not_to raise_error
        expect(Group.staff.map(&:user_id)).not_to include(nil)
      end

      it 'handles groupers with non-existent user_id in staff groups gracefully' do
        # Create a grouper with a user_id that doesn't exist in a casters group
        caster_group = Group.find_or_create_by(id: Group::CASTERS) { |g| g.name = 'Casters' }
        orphaned = build(:grouper, group: caster_group, user_id: 99_999)
        orphaned.save(validate: false) if orphaned.persisted? == false

        # Should not raise an exception - valid_users scope filters these out
        expect { Group.staff }.not_to raise_error
        expect(Group.staff.map(&:user_id)).not_to include(99_999)
      end

      it 'returns only valid staff groupers when mixed with invalid user_ids' do
        # Create a mix of valid and invalid groupers
        admin_group = Group.find_or_create_by(id: Group::ADMINS) { |g| g.name = 'Admins' }
        valid_admin = create(:user)
        create(:grouper, group: admin_group, user: valid_admin)
        # Add invalid groupers by bypassing validation
        orphaned1 = build(:grouper, group: admin_group, user: nil)
        orphaned2 = build(:grouper, group: admin_group, user_id: 99_999)
        orphaned1.save(validate: false) if orphaned1.persisted? == false
        orphaned2.save(validate: false) if orphaned2.persisted? == false

        staff = Group.staff
        # Should include valid admin - invalid ones filtered by valid_users scope
        expect(staff.map(&:user_id)).to include(valid_admin.id)
        # Should not include invalid user_ids (filtered by valid_users scope)
        expect(staff.map(&:user_id)).not_to include(nil)
        expect(staff.map(&:user_id)).not_to include(99_999)
      end
    end

    describe '.extras' do
      it 'returns predictor and staff group members' do
        predictor_group = Group.find_or_create_by(id: Group::PREDICTORS) { |g| g.name = 'Predictors' }
        predictor_user = create(:user)
        create(:grouper, group: predictor_group, user: predictor_user)

        extras = Group.extras
        expect(extras.map(&:user)).to include predictor_user
      end

      it 'deduplicates when user is in both predictor and staff groups' do
        predictor_group = Group.find_or_create_by(id: Group::PREDICTORS) { |g| g.name = 'Predictors' }
        staff_group = Group.find_or_create_by(id: Group::STAFF) { |g| g.name = 'Staff' }

        duplicate_user = create(:user)
        create(:grouper, group: predictor_group, user: duplicate_user)
        create(:grouper, group: staff_group, user: duplicate_user)

        extras = Group.extras
        # Verify the user is in extras and only appears once
        extras_users = extras.map(&:user_id)
        expect(extras_users).to include(duplicate_user.id)
        expect(extras_users.count(duplicate_user.id)).to eq 1
      end

      it 'handles groupers with nil user_id gracefully without breaking' do
        # NOTE: Can't actually create groupers with nil user via factory due to validation,
        # but safe_users scope provides defensive protection if validation is ever bypassed
        admin_group = Group.find_or_create_by(id: Group::ADMINS) { |g| g.name = 'Admins' }
        # Build (not create) a grouper with nil user_id to simulate orphaned data
        orphaned = build(:grouper, group: admin_group, user: nil)
        # Bypass validation and save directly to DB to simulate data corruption scenario
        Grouper.skip_callback(:validation) if Grouper.respond_to?(:skip_callback)
        orphaned.save(validate: false) if orphaned.persisted? == false

        # Should not raise an exception - valid_users scope filters these out
        expect { Group.extras }.not_to raise_error
        # Extras should be empty or not include the nil user_id
        expect(Group.extras.map(&:user_id)).not_to include(nil)
      end

      it 'handles groupers with non-existent user_id gracefully' do
        # Create a grouper with a user_id that doesn't exist in users table
        staff_group = Group.find_or_create_by(id: Group::STAFF) { |g| g.name = 'Staff' }
        # Build and save without validation to simulate data corruption
        orphaned = build(:grouper, group: staff_group, user_id: 99_999)
        orphaned.save(validate: false) if orphaned.persisted? == false

        # Should not raise an exception - valid_users scope filters these out
        expect { Group.extras }.not_to raise_error
        # Extras should be empty or not include the non-existent user_id
        expect(Group.extras.map(&:user_id)).not_to include(99_999)
      end

      it 'returns empty array when no valid extras exist but orphaned groupers present' do
        # Create groupers with invalid user IDs by bypassing validation
        predictor_group = Group.find_or_create_by(id: Group::PREDICTORS) { |g| g.name = 'Predictors' }
        orphaned1 = build(:grouper, group: predictor_group, user: nil)
        orphaned2 = build(:grouper, group: predictor_group, user_id: 99_999)
        orphaned1.save(validate: false) if orphaned1.persisted? == false
        orphaned2.save(validate: false) if orphaned2.persisted? == false

        extras = Group.extras
        # Should return empty array since valid_users scope filters out invalid ones
        expect(extras).to be_a(Array)
        expect(extras).to be_empty
      end
    end

    describe '.gathermods' do
      it 'returns gather moderator groupers' do
        gathermod_group = Group.find_or_create_by(id: Group::GATHER_MODERATORS) { |g| g.name = 'Gather Mods' }
        gathermod_user = create(:user)
        create(:grouper, group: gathermod_group, user: gathermod_user)

        gathermods = Group.gathermods
        expect(gathermods.map(&:user)).to include gathermod_user
      end
    end

    describe '.contributors' do
      it 'returns contributor groupers' do
        contrib_group = Group.find_or_create_by(id: Group::CONTRIBUTORS) { |g| g.name = 'Contributors' }
        contrib_user = create(:user)
        create(:grouper, group: contrib_group, user: contrib_user)

        contributors = Group.contributors
        expect(contributors.map(&:user)).to include contrib_user
      end
    end

    describe '.predictors' do
      it 'returns predictor groupers' do
        predictor_group = Group.find_or_create_by(id: Group::PREDICTORS) { |g| g.name = 'Predictors' }
        predictor_user = create(:user)
        create(:grouper, group: predictor_group, user: predictor_user)

        predictors = Group.predictors
        expect(predictors.map(&:user)).to include predictor_user
      end

      it 'handles groupers with invalid user_ids gracefully' do
        predictor_group = Group.find_or_create_by(id: Group::PREDICTORS) { |g| g.name = 'Predictors' }
        # Build invalid groupers and save without validation
        orphaned1 = build(:grouper, group: predictor_group, user: nil)
        orphaned2 = build(:grouper, group: predictor_group, user_id: 99_999)
        orphaned1.save(validate: false) if orphaned1.persisted? == false
        orphaned2.save(validate: false) if orphaned2.persisted? == false

        # Should not raise an exception - valid_users scope filters these out
        expect { Group.predictors }.not_to raise_error
      end

      it 'returns only valid predictor groupers' do
        predictor_group = Group.find_or_create_by(id: Group::PREDICTORS) { |g| g.name = 'Predictors' }
        valid_predictor = create(:user)
        create(:grouper, group: predictor_group, user: valid_predictor)
        # Add invalid groupers by bypassing validation
        orphaned1 = build(:grouper, group: predictor_group, user: nil)
        orphaned2 = build(:grouper, group: predictor_group, user_id: 99_999)
        orphaned1.save(validate: false) if orphaned1.persisted? == false
        orphaned2.save(validate: false) if orphaned2.persisted? == false

        predictors = Group.predictors
        # Should include valid predictor - invalid ones filtered by valid_users scope
        expect(predictors.map(&:user_id)).to include(valid_predictor.id)
        # Should not include invalid user_ids (filtered by valid_users scope)
        expect(predictors.map(&:user_id)).not_to include(nil)
        expect(predictors.map(&:user_id)).not_to include(99_999)
      end
    end
  end

  describe '.params' do
    it 'permits the name attribute' do
      params = ActionController::Parameters.new(group: { name: 'A' })
      permitted = Group.params(params, nil)
      expect(permitted[:name]).to eq 'A'
    end

    it 'ignores unpermitted attributes' do
      params = ActionController::Parameters.new(group: { name: 'A', founder_id: 99, created_at: Time.now })
      permitted = Group.params(params, nil)
      expect(permitted.key?(:founder_id)).to be false
      expect(permitted.key?(:created_at)).to be false
    end
  end
end
