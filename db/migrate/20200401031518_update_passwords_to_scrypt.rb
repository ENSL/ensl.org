
ENV['SCRYPT_MAX_TIME'] ||= "1"
class UpdatePasswordsToScrypt < ActiveRecord::Migration[6.0]
  require 'scrypt'

  def up
    puts("SCRYPT_MAX_TIME=%s" % ENV['SCRYPT_MAX_TIME'])
    puts("Migration takes about %0.0f seconds." % ENV['SCRYPT_MAX_TIME'].to_f*User.all.count*3)
    SCrypt::Engine.calibrate!(max_time: ENV['SCRYPT_MAX_TIME'].to_f)
    ActiveRecord::Base.transaction do
      User.all.order(:id).each do |user|
        user.team = nil unless user&.team&.present?
        if user.valid?
          user.update_password
          user.save!
          puts("User %s (%d) updated" % [user.username, user.id])
        end
      end
    end
  end
end
