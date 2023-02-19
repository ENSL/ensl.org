class ChangeTypeOfProfileParsedSignature < ActiveRecord::Migration[4.2]
  def up
    change_column :profiles, :signature_parsed, :text
  end
end
