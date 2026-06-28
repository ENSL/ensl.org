# frozen_string_literal: true

class MigrateUserVersionsToPaperTrail < ActiveRecord::Migration[8.1]
  class LegacyUserVersion < ActiveRecord::Base
    self.table_name = 'user_versions'
  end

  class PaperTrailVersion < ActiveRecord::Base
    self.table_name = 'versions'
  end

  def up
    return unless table_exists?(:user_versions)
    return unless table_exists?(:versions)

    say_with_time 'Migrating user_versions rows into versions' do
      LegacyUserVersion.find_in_batches(batch_size: 1000) do |batch|
        rows = batch.map { |legacy| build_paper_trail_row(legacy) }
        PaperTrailVersion.insert_all(rows) if rows.any?
      end
    end

    drop_table :user_versions
  end

  def down
    create_table :user_versions do |t|
      t.string :lastip
      t.string :steamid
      t.datetime :updated_at
      t.integer :user_id
      t.string :username
      t.integer :version
    end

    add_index :user_versions, :steamid
    add_index :user_versions, :user_id

    say_with_time 'Restoring user_versions rows from versions' do
      versions_scope = PaperTrailVersion.where(item_type: 'User', event: 'update').order(:created_at, :id)

      versions_scope.find_in_batches(batch_size: 1000) do |batch|
        rows = batch.filter_map do |version|
          object = parse_object(version.object)
          next unless object.is_a?(Hash)

          {
            user_id: version.item_id,
            username: object['username'],
            steamid: object['steamid'],
            lastip: object['lastip'],
            updated_at: version.created_at,
            version: nil
          }
        end

        LegacyUserVersion.insert_all(rows) if rows.any?
      end
    end
  end

  private

  def build_paper_trail_row(legacy)
    object = {
      'username' => legacy.username,
      'steamid' => legacy.steamid,
      'lastip' => legacy.lastip,
      'email' => nil,
      'updated_at' => legacy.updated_at
    }

    {
      item_type: 'User',
      item_id: legacy.user_id,
      event: 'update',
      whodunnit: nil,
      object: PaperTrail.serializer.dump(object),
      created_at: legacy.updated_at || Time.current
    }
  end

  def parse_object(serialized_object)
    PaperTrail.serializer.load(serialized_object)
  rescue StandardError
    nil
  end
end
