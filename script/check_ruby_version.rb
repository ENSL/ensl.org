#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'

ROOT = File.expand_path('..', __dir__)
DOCKERFILE = File.join(ROOT, 'Dockerfile')
GEMFILE = File.join(ROOT, 'Gemfile')

def fetch_json(uri, headers = {})
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.get(uri.request_uri, headers)
  end

  abort "Could not fetch #{uri}: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

def configured_versions
  dockerfile = File.read(DOCKERFILE)
  gemfile = File.read(GEMFILE)
  docker_version = dockerfile[/^FROM\s+ruby:([0-9]+\.[0-9]+\.[0-9]+)\b/, 1]
  gemfile_version = gemfile[/^ruby\s+['"]([0-9]+\.[0-9]+\.[0-9]+)['"]/, 1]

  abort "Could not find a stable Ruby Docker tag in #{DOCKERFILE}" unless docker_version
  abort "Could not find a Ruby version in #{GEMFILE}" unless gemfile_version

  [docker_version, gemfile_version]
end

def latest_stable_version
  token_uri = URI('https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/ruby:pull')
  token = fetch_json(token_uri).fetch('token')
  tags_uri = URI('https://registry-1.docker.io/v2/library/ruby/tags/list?n=10000')
  tags = fetch_json(tags_uri, 'Authorization' => "Bearer #{token}").fetch('tags')

  tags.filter_map do |tag|
    Gem::Version.new(tag) if tag.match?(/\A\d+\.\d+\.\d+\z/)
  end.max.to_s
end

docker_version, gemfile_version = configured_versions
unless docker_version == gemfile_version
  abort "Dockerfile Ruby version #{docker_version} does not match Gemfile Ruby version #{gemfile_version}"
end

latest_version = latest_stable_version
unless docker_version == latest_version
  abort "Ruby #{docker_version} is not the latest stable Docker image tag (#{latest_version})"
end

puts "Ruby #{docker_version} matches the Gemfile and the latest stable Docker image tag."
