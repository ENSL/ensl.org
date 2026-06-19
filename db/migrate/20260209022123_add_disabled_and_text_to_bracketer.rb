# frozen_string_literal: true

class AddDisabledAndTextToBracketer < ActiveRecord::Migration[8.1]
  def change
    add_column :bracketers, :disabled, :boolean
    add_column :bracketers, :custom_text, :string
  end
end
