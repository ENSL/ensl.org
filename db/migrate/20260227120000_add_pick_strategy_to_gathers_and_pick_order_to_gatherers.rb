# frozen_string_literal: true

class AddPickStrategyToGathersAndPickOrderToGatherers < ActiveRecord::Migration[8.1]
  PICK_STRATEGY_DEFAULT = '1-2-2-2-2-1'
  COMPLETED_GATHER_SIZE = 12

  class MigrationGather < ActiveRecord::Base
    self.table_name = 'gathers'
  end

  class MigrationGatherer < ActiveRecord::Base
    self.table_name = 'gatherers'
  end

  def up
    add_column :gathers, :pick_strategy, :string, null: false, default: PICK_STRATEGY_DEFAULT
    add_column :gatherers, :pick_order, :integer
    add_index :gatherers, %i[gather_id pick_order]

    backfill_pick_order_for_completed_gathers
  end

  def down
    remove_index :gatherers, %i[gather_id pick_order]
    remove_column :gatherers, :pick_order
    remove_column :gathers, :pick_strategy
  end

  private

  def backfill_pick_order_for_completed_gathers
    say_with_time 'Backfilling gatherers.pick_order for completed gathers' do
      MigrationGather.where.not(captain1_id: nil, captain2_id: nil).find_each(batch_size: 200) do |gather|
        gatherers = MigrationGatherer.where(gather_id: gather.id)

        next unless gatherers.count == COMPLETED_GATHER_SIZE
        next unless gatherers.where.not(team: nil).count == COMPLETED_GATHER_SIZE

        captain1 = gatherers.find_by(id: gather.captain1_id)
        captain2 = gatherers.find_by(id: gather.captain2_id)
        next unless captain1 && captain2

        picked_players = gatherers.where.not(id: [captain1.id, captain2.id]).where.not(team: nil)
                                  .order(updated_at: :asc, id: :asc)
        next unless picked_players.count == (COMPLETED_GATHER_SIZE - 2)

        MigrationGatherer.transaction do
          captain1.update_columns(pick_order: 1, updated_at: captain1.updated_at)
          captain2.update_columns(pick_order: 2, updated_at: captain2.updated_at)

          picked_players.each_with_index do |player, index|
            player.update_columns(pick_order: index + 3, updated_at: player.updated_at)
          end
        end
      rescue StandardError
        next
      end
    end
  end
end
