# frozen_string_literal: true

# Ensure compatibility with gems that call ActiveSupport::Deprecation.warn directly.
# Rails 8.1 makes `warn` a private class method.
ActiveSupport::Deprecation.singleton_class.send(:public, :warn) if ActiveSupport::Deprecation.respond_to?(:warn, true)
