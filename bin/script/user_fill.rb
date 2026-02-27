#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../config/environment'

def unique_email_for(base, exclude_id = nil)
  local, domain = base.split('@', 2)
  candidate = base
  suffix = 1

  while User.where('LOWER(email) = ?', candidate.downcase).where.not(id: exclude_id).exists?
    candidate = "#{local}+#{suffix}@#{domain}"
    suffix += 1
  end

  candidate
end

created = 0
updated = 0

ActiveRecord::Base.transaction do
  (1..20).each do |i|
    username = "user#{i}"
    user = User.where('LOWER(username) = ?', username.downcase).first_or_initialize

    user.username = username
    user.email = unique_email_for("#{username}@ensl.org", user.id)
    user.firstname = 'ENSL'
    user.lastname = 'Player'
    user.country = 'EU'
    user.raw_password = 'foo'

    was_new = user.new_record?
    user.save!
    was_new ? created += 1 : updated += 1
  end
end

puts 'Users ready: user1..user20 (password: foo)'
puts "Created: #{created}, Updated: #{updated}"
