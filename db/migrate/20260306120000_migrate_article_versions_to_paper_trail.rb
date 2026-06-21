class MigrateArticleVersionsToPaperTrail < ActiveRecord::Migration[8.1]
  LEGACY_EVENT = 'legacy_import'.freeze
  FALLBACK_TIMESTAMP = Time.utc(1970, 1, 1).freeze

  class LegacyArticleVersion < ActiveRecord::Base
    self.table_name = 'article_versions'
  end

  class PaperTrailVersion < ActiveRecord::Base
    self.table_name = 'versions'
  end

  def up
    return unless table_exists?(:article_versions)
    return unless table_exists?(:versions)

    ensure_versions_object_supports_large_payloads

    say_with_time 'Migrating article_versions records to PaperTrail versions' do
      migrated = 0

      LegacyArticleVersion.order(:id).find_each do |legacy|
        object = serialized_object_for(legacy)
        created_at = legacy.updated_at || legacy.created_at || FALLBACK_TIMESTAMP

        next if PaperTrailVersion.exists?(
          item_type: 'Article',
          item_id: legacy.article_id,
          event: LEGACY_EVENT,
          created_at: created_at,
          object: object
        )

        PaperTrailVersion.create!(
          item_type: 'Article',
          item_id: legacy.article_id,
          event: LEGACY_EVENT,
          whodunnit: nil,
          object: object,
          created_at: created_at
        )
        migrated += 1
      end

      migrated
    end
  end

  def down
    return unless table_exists?(:versions)

    PaperTrailVersion.where(item_type: 'Article', event: LEGACY_EVENT).delete_all
  end

  private

  def serialized_object_for(legacy)
    attrs = {
      'id' => legacy.article_id,
      'title' => legacy.title,
      'text' => legacy.text,
      'text_parsed' => legacy.text_parsed,
      'text_coding' => legacy.text_coding,
      'version' => legacy.version,
      'created_at' => legacy.created_at,
      'updated_at' => legacy.updated_at
    }

    return PaperTrail.serializer.dump(attrs) if defined?(PaperTrail)

    YAML.dump(attrs)
  end

  def ensure_versions_object_supports_large_payloads
    return unless mysql_adapter?
    return unless column_exists?(:versions, :object)

    object_column = connection.columns(:versions).find { |column| column.name == 'object' }
    return if object_column&.sql_type.to_s.downcase.include?('longtext')

    execute 'ALTER TABLE versions MODIFY object LONGTEXT'
  end

  def mysql_adapter?
    connection.adapter_name.to_s.downcase.include?('mysql')
  end
end
