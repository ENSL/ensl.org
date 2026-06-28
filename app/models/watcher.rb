# frozen_string_literal: true

class Watcher < ApplicationRecord
  belongs_to :movie, optional: true
  belongs_to :user, optional: true
end
