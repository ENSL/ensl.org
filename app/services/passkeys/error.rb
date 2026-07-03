# frozen_string_literal: true

module Passkeys
  class Error < StandardError
    attr_reader :status

    def initialize(message, status:)
      super(message)
      @status = status
    end
  end
end
