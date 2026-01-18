# Toggle debug prints throughout the app/tests using ENV['DEBUG_PRINTS']
# Set to a truthy value to enable extra prints temporarily.
Rails.configuration.x.debug_prints = ENV['DEBUG_PRINTS'] && ENV['DEBUG_PRINTS'] != '' if defined?(Rails)
