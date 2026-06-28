# frozen_string_literal: true

class Rate < ApplicationRecord
  has_many :ratings, dependent: :destroy
end
