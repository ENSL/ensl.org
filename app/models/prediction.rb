# frozen_string_literal: true

# == Schema Information
#
# Table name: predictions
#
#  id         :integer          not null, primary key
#  result     :integer
#  score1     :integer
#  score2     :integer
#  created_at :datetime
#  updated_at :datetime
#  match_id   :integer
#  user_id    :integer
#
# Indexes
#
#  index_predictions_on_match_id  (match_id)
#  index_predictions_on_user_id   (user_id)
#

class Prediction < ApplicationRecord
  include Extra

  # attr_protected :id, :created_at, :updated_at, :result

  validates :match, :user, presence: true
  validates :score1, inclusion: { in: 0..99, message: 'Invalid score' }
  validates :score2, inclusion: { in: 0..99, message: 'Invalid score' }
  validates :match_id, uniqueness: { scope: :user_id }

  scope :with_contest, -> { includes({ match: :contest }) }

  belongs_to :match, optional: true
  belongs_to :user, optional: true

  def can_create?(cuser)
    cuser and match.match_time.future? and !match.score1 and !match.score2 and !cuser.predictions.exists?(match_id: match.id)
  end

  def self.params(params, _cuser)
    params.require(:prediction).permit(:result, :score1, :score2, :match_id, :user_id)
  end

  def self.build_for_actor(params, actor)
    prediction = new(self.params(params, actor))
    prediction.user = actor
    prediction
  end
end
