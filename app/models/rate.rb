# frozen_string_literal: true

class Rate < ActiveRecord::Base
  has_many :ratings
end
