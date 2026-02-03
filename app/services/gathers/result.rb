module Gathers
  Result = Struct.new(:gather, :gatherer, :vote, :error, keyword_init: true) do
    def success?
      error.nil?
    end
  end
end
