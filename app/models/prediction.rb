# == Schema Information
#
# Table name: predictions
#
#  id         :integer          not null, primary key
#  match_id   :integer
#  user_id    :integer
#  score1     :integer
#  score2     :integer
#  created_at :datetime
#  updated_at :datetime
#  result     :integer
#

class Prediction < ActiveRecord::Base
  include Extra

  #attr_protected :id, :created_at, :updated_at, :result

  validates_presence_of :match, :user
  validates_inclusion_of :score1, :in => 0..99, :message => "Invalid score"
  validates_inclusion_of :score2, :in => 0..99, :message => "Invalid score"
  validates_uniqueness_of :match_id, :scope => :user_id

  scope :with_contest, -> { include({:match => :contest}) }

  belongs_to :match
  belongs_to :user

  def can_create? cuser
    cuser and match.match_time.future? and !match.score1 and !match.score2 and !cuser.predictions.exists?(:match_id => match.id)
  end
end
