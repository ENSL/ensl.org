# frozen_string_literal: true

class Rating < ActiveRecord::Base
  belongs_to :rateable, polymorphic: true, optional: true
  belongs_to :rate, optional: true
  belongs_to :user, optional: true
end
