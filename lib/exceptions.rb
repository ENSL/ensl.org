module Exceptions
  class AccessError < StandardError; end
  class UserRegistrationReq < AccessError; end
  class Error < StandardError; end
end
