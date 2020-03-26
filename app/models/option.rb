# == Schema Information
#
# Table name: options
#
#  id         :integer          not null, primary key
#  option     :string(255)
#  votes      :integer          default("0"), not null
#  created_at :datetime
#  updated_at :datetime
#  poll_id    :integer
#
# Indexes
#
#  index_options_on_poll_id  (poll_id)
#

class Option < ActiveRecord::Base
  include Extra

  #attr_protected :id, :updated_at, :created_at, :votes

  validates_length_of :option, :in => 1..30

  has_many :real_votes, :class_name => "Vote", :as => :votable
  belongs_to :poll, :optional => true

  def to_s
    self.option
  end

  def self.params(params, cuser)
    # FIXME: check this
    params.require(:option).permit(:option, :votes, :poll_id)
  end
end
