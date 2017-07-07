class ChangeTypeOfProfileParsedSignature < ActiveRecord::Migration
  def up
    change_column :profiles, :signature_parsed, :text
  end
end
