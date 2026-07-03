# frozen_string_literal: true

class PasskeyCredential < ApplicationRecord
  belongs_to :user

  validates :external_id, :public_key, presence: true
  validates :external_id, uniqueness: true
end
