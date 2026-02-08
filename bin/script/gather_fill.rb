#!/usr/bin/env ruby
# frozen_string_literal: true

# Loads 11 users to most recent gather for dev env.

require_relative '../../config/environment'

gather = Gather.order(created_at: :desc).first
raise 'No gathers found' unless gather

joined = []
missing = []

ActiveRecord::Base.transaction do
  (1..11).each do |i|
    username = "user#{i}"
    user = User.find_by(username: username)

    if user.nil?
      missing << username
      next
    end

    gatherer = Gatherer.find_or_create_by!(gather: gather, user: user)
    joined << gatherer.user.username
  end
end

puts "Gather: #{gather.id}"
puts "Joined: #{joined.sort.join(', ')}" unless joined.empty?
puts "Missing users: #{missing.sort.join(', ')}" unless missing.empty?
