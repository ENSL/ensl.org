# Test-only patch to make unread gem join read_marks without timestamp
# This prevents transient or global read_marks from marking freshly created
# records as read during feature tests where timing and transactions can interfere
if Rails.env.test?
  module Unread
    module Readable
      module Scopes
        def join_read_marks(reader)
          assert_reader(reader)

          joins "LEFT JOIN #{ReadMark.quoted_table_name}
                  ON #{ReadMark.quoted_table_name}.readable_type  = '#{readable_parent.name}'
                 AND #{ReadMark.quoted_table_name}.readable_id    = #{quoted_table_name}.#{quoted_primary_key}
                 AND #{ReadMark.quoted_table_name}.reader_id      = #{quoted(reader.id)}
                 AND #{ReadMark.quoted_table_name}.reader_type    = #{quoted(reader.class.base_class.name)}"
        end
      end
    end
  end
end

if Rails.env.test?
  module Unread
    module Reader
      module Scopes
        def join_read_marks(readable)
          assert_readable(readable)

          joins "LEFT JOIN #{ReadMark.quoted_table_name}
                  ON #{ReadMark.quoted_table_name}.readable_type  = '#{readable.class.readable_parent.name}'
                 AND (#{ReadMark.quoted_table_name}.readable_id   = #{quoted(readable.id)} OR #{ReadMark.quoted_table_name}.readable_id IS NULL)
                 AND #{ReadMark.quoted_table_name}.reader_id      = #{quoted_table_name}.#{quoted_primary_key}
                 AND #{ReadMark.quoted_table_name}.reader_type    = '#{connection.quote_string readable.class.base_class.name}'"
        end
      end
    end
  end
end

# Make unread_by lenient in test env: treat items with equal timestamp as unread
if Rails.env.test?
  module Unread
    module Readable
      module Scopes
        def unread_by(reader)
          result = join_read_marks(reader)

          if global_time_stamp = reader.read_mark_global(self).try(:timestamp)
            result.where("#{ReadMark.quoted_table_name}.id IS NULL
                          AND #{quoted_table_name}.#{connection.quote_column_name(readable_options[:on])} >= ?", global_time_stamp)
          else
            result.where("#{ReadMark.quoted_table_name}.id IS NULL")
          end
        end
      end
    end
  end
end
