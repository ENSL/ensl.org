# Compatibility shim for connection_pool initializer argument styles.
# ActiveSupport may call ConnectionPool.new(pool_options) with a positional Hash.
# Newer connection_pool gem versions expect keyword args. Prepend a small
# adapter so both styles work.
module ConnectionPoolInitializeCompatibility
  def initialize(*args, **kwargs, &blk)
    if args.size == 1 && args.first.is_a?(Hash) && kwargs.empty?
      super(**args.first, &blk)
    else
      super(*args, **kwargs, &blk)
    end
  end
end

begin
  require 'connection_pool'
  unless ConnectionPool < ConnectionPoolInitializeCompatibility
    ConnectionPool.prepend(ConnectionPoolInitializeCompatibility)
  end
rescue LoadError
  # connection_pool gem not available yet; ActiveSupport will require it later
end
