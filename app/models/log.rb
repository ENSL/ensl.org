# frozen_string_literal: true

class Log < ApplicationRecord
  belongs_to :server, optional: true
end
