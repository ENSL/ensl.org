# frozen_string_literal: true

module Controllers
  module JsonHelpers
    def json
      @json ||= JSON.parse(response.body)
    end

    def json_sym
      @json_sym ||= JSON.parse(response.body, symbolize_names: true)
    end
  end
end
