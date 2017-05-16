module Zimbra
  class AuthToken
    attr_accessor :token, :lifetime, :created_at

    def initialize(args = {})
      self.created_at = Time.now
      self.token = args[:token]
      self.lifetime = args[:lifetime]
    end

    def expired?
      created_at + (lifetime / 1000) < Time.now
    end
  end
end