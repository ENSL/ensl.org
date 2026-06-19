# frozen_string_literal: true

module Exceptions
  class AccessError < StandardError; end
  class UserRegistrationReq < AccessError; end
  class Error < StandardError; end
end
