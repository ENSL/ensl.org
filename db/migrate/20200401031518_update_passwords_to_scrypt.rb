# frozen_string_literal: true

ENV['SCRYPT_MAX_TIME'] ||= '1'
class UpdatePasswordsToScrypt < ActiveRecord::Migration[4.2][6.0]
  require 'scrypt'

  def up
    puts('SCRYPT_MAX_TIME=%s' % ENV['SCRYPT_MAX_TIME'])
    SCrypt::Engine.calibrate!(max_time: ENV['SCRYPT_MAX_TIME'].to_f)

    puts('Updating passwords to scrypt...')

    # Migrate passwords to scrypt
    User.all.order(:id).find_each(batch_size: 200) do |user|
      user.team = nil unless user&.team&.present?
      user.update_password
      user.save!(validate: false)
      print(format('%s (%d) ', user.username, user.id))
    rescue StandardError => e
      puts(format('User %s (%d) skipped: %s', user.username, user.id, e.message))
    end
  end
end
