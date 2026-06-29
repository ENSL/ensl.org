# frozen_string_literal: true

module Articles
  class VersionHistory
    def initialize(article)
      @article = article
    end

    def versions
      @article.versions.reorder(created_at: :desc, id: :desc)
    end

    def snapshots_for(version_records)
      version_records.each_with_object({}) do |version_record, snapshots|
        snapshots[version_record.id] = snapshot_for(version_record)
      end
    end

    def version_numbers_for(version_records)
      total = version_records.length

      version_records.each_with_index.to_h do |version_record, index|
        [version_record.id, total - index]
      end
    end

    def version_number_for(version_record)
      @article.versions.where('id <= ?', version_record.id).count
    end

    def snapshot_for(version_record)
      version_record.reify || @article
    rescue StandardError
      @article
    end

    def revert_to!(version_record)
      snapshot = snapshot_for(version_record)
      return false unless snapshot

      @article.assign_attributes(
        title: snapshot.title,
        text: snapshot.text,
        text_parsed: snapshot.text_parsed,
        text_coding: snapshot.text_coding
      )

      @article.save
    rescue StandardError
      false
    end
  end
end
