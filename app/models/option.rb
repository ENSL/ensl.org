class Option < ActiveRecord::Base
  include Extra

  attr_protected :id, :updated_at, :created_at, :votes

  validates_length_of :option, :in => 1..30

  has_many :real_votes, :class_name => "Vote", :as => :votable
  belongs_to :poll

  def to_s
    self.option
  end
end
