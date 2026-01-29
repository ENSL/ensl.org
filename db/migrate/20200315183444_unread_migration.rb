class UnreadMigration < ActiveRecord::Migration[6.0]
  def self.up
    return if table_exists?(:read_marks)

    create_table :read_marks, force: true, options: create_options do |t|
      t.string   :readable_type, null: false
      t.bigint   :readable_id,   null: false
      t.string   :reader_type,   null: false
      t.bigint   :reader_id,     null: false
      t.datetime :timestamp
    end

    add_index :read_marks, %i[reader_id reader_type readable_type readable_id],
              name: 'read_marks_reader_readable_index', unique: true
  end

  def self.down
    drop_table :read_marks, if_exists: true
  end

  def self.create_options
    options = ''
    if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter) &&
       ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
      options = 'DEFAULT CHARSET=latin1'
    end
    options
  end
end
