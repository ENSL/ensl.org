#!/usr/bin/env ruby
# frozen_string_literal: true

# Loads 11 users to most recent gather for dev env.

require_relative '../config/environment'

raise 'gather_fill is only intended for development environment' unless Rails.env.development?

gather = Gather.order(created_at: :desc).first
raise 'No gathers found' unless gather

joined = []
created = []

def find_or_create_dev_user(username)
  user = User.find_or_create_by!(username: username) do |new_user|
    new_user.email = "#{username}@dev.local"
    new_user.raw_password = 'developer'
  end

  created_now = user.respond_to?(:previously_new_record?) && user.previously_new_record?
  [user, created_now]
end

ActiveRecord::Base.transaction do
  (1..11).each do |i|
    username = "user#{i}"
    user, created_now = find_or_create_dev_user(username)
    created << username if created_now

    gatherer = Gatherer.find_or_create_by!(gather: gather, user: user)
    joined << user.username
  end
end

puts "Gather: #{gather.id}"
puts "Joined: #{joined.sort.join(', ')}" unless joined.empty?
puts "Created users: #{created.sort.join(', ')}" unless created.empty?
