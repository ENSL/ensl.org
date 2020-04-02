
ENV['SCRYPT_MAX_TIME'] ||= "0.03"
class UpdatePasswordsToScrypt < ActiveRecord::Migration[6.0]
  require 'scrypt'

  def up
    SCrypt::Engine.calibrate!(max_time: ENV['SCRYPT_MAX_TIME'].to_f)
    ActiveRecord::Base.transaction do
      User.all.order(:id).each do |user|
        user.team = nil unless user&.team&.present?
        if user.valid?
          user.update_password
          user.save!
        end
      end
    end
  end
end
