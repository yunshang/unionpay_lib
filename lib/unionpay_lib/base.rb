module UnionpayLib
  Base = Class.new do
    class << self

      def faraday
        Faraday.new(@@endpoint, :ssl => {:verify => false})
      end

      def sign(data)
        Base64.strict_encode64(
          @@pkcs12.key.sign(OpenSSL::Digest::SHA1.new,
                            Digest::SHA1.hexdigest(data)) )
      end
    end
  end
end
