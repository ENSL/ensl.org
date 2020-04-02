class UpdatePasswordsToScrypt < ActiveRecord::Migration[6.0]
  require 'scrypt'
  require 'user'

  def up
    SCrypt::Engine.calibrate!(max_time: 0.03)
    ActiveRecord::Base.transaction do
      User.all.order(:id).each do |user|
        user.update_password
        user.save!
      end
    end
  end
end
