#!/usr/bin/env ruby
# frozen_string_literal: true

require 'uri'
require 'faraday'
require 'nokogiri'

# Simple Rails link crawler (GET-only) for local dev instances.
# - Skips external links
# - Skips destructive methods (only GET is issued)
# - Reports broken links (>= 400) and request errors
#
# Usage:
#   BASE_URL=http://localhost:3000 bin/tools/rails_link_crawl.rb
#   bin/tools/rails_link_crawl.rb http://localhost:3000

base_url = ENV['BASE_URL'] || ARGV[0] || 'http://localhost:4000'

begin
  base_uri = URI(base_url)
rescue URI::InvalidURIError
  warn "Invalid BASE_URL: #{base_url}"
  exit 1
end

allowed_host = base_uri.host
allowed_scheme = base_uri.scheme

conn = Faraday.new(url: base_uri) do |f|
  f.options.timeout = 10
  f.options.open_timeout = 5
  f.adapter Faraday.default_adapter
end

visited = Set.new
queue = [base_uri]
broken = []
redirects = []

RED = "\e[31m"
RESET = "\e[0m"
BROKEN_MARK = '✗'

def colorize(text, color)
  return text unless $stdout.tty?

  "#{color}#{text}#{RESET}"
end

def normalize_href(href)
  return nil if href.nil?

  href = href.to_s.strip
  return nil if href.empty?
  return nil if href.start_with?('#')
  return nil if href.start_with?('mailto:')
  return nil if href.start_with?('tel:')
  return nil if href.start_with?('javascript:')

  href
end

def same_origin?(uri, host, scheme)
  uri.host == host && uri.scheme == scheme
end

def strip_fragment(uri)
  uri.fragment = nil
  uri
end

while (current = queue.shift)
  current = strip_fragment(current)
  next if visited.include?(current.to_s)

  visited.add(current.to_s)

  puts "GET #{current}"

  begin
    response = conn.get(current.request_uri)
  rescue StandardError => e
    broken << [current.to_s, e.class.to_s, e.message]
    next
  end

  status = response.status.to_i

  if status >= 400
    broken << [current.to_s, status, response.reason_phrase]
    puts colorize("#{BROKEN_MARK} #{status} #{current} #{response.reason_phrase}".strip, RED)
    next
  end

  if status >= 300 && status < 400
    location = response.headers['location']
    if location
      begin
        target = strip_fragment(URI.join(base_uri.to_s, location))
        if same_origin?(target, allowed_host, allowed_scheme)
          redirects << [current.to_s, status, target.to_s]
          queue << target
        end
      rescue URI::InvalidURIError
        redirects << [current.to_s, status, location]
      end
    end
    next
  end

  content_type = response.headers['content-type'].to_s
  next unless content_type.include?('text/html')

  doc = Nokogiri::HTML(response.body)
  doc.css('a[href]').each do |a|
    href = normalize_href(a['href'])
    next unless href

    begin
      target = strip_fragment(URI.join(base_uri.to_s, href))
    rescue URI::InvalidURIError
      broken << [current.to_s, 'invalid_href', href]
      puts colorize("#{BROKEN_MARK} invalid_href #{current} #{href}".strip, RED)
      next
    end

    next unless same_origin?(target, allowed_host, allowed_scheme)

    queue << target
  end
end

puts "Crawl complete. Visited: #{visited.size}"

if redirects.any?
  puts "Redirects: #{redirects.size}"
  redirects.each do |from, status, to|
    puts "  #{status} #{from} -> #{to}"
  end
end

if broken.any?
  puts "Broken links: #{broken.size}"
  broken.each do |url, status, message|
    puts colorize("  #{BROKEN_MARK} #{status} #{url} #{message}".strip, RED)
  end
  exit 2
else
  puts 'No broken internal links found.'
end
