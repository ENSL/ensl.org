# frozen_string_literal: true

ENV['SCRYPT_MAX_TIME'] ||= '1'
class UpdatePasswordsToScrypt < ActiveRecord::Migration[4.2][6.0]
  require 'scrypt'

  def up
    puts(format('SCRYPT_MAX_TIME=%<value>s', value: ENV['SCRYPT_MAX_TIME']))
    SCrypt::Engine.calibrate!(max_time: ENV['SCRYPT_MAX_TIME'].to_f)

    puts('Updating passwords to scrypt...')

    # Migrate passwords to scrypt
    User.all.order(:id).find_each(batch_size: 200) do |user|
      user.team = nil unless user&.team&.present?
      user.update_password
      user.save!(validate: false)
      print(format('%<username>s (%<id>d) ', username: user.username, id: user.id))
    rescue StandardError => e
      puts(format('User %<username>s (%<id>d) skipped: %<message>s', username: user.username, id: user.id,
                                                                     message: e.message))
    end
  end
end
