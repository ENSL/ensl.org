module ActionDispatch
  class Cookies
    class SignedCookieJar
      def initialize(parent_jar, secret)
        ensure_secret_secure(secret)
        @parent_jar = parent_jar
        @verifier   = MessageVerifier.new(secret,:serializer=>YAML)
      end
    end
  end
end
