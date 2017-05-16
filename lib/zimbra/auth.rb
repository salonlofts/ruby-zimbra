module Zimbra
  class Auth
    def self.login(username, password)
      AuthService.login(username, password)
    end
  end

  class AuthService < Handsoap::Service
    include HandsoapErrors
    include Zimbra::HandsoapNamespaces
    extend HandsoapUriOverrides

    def on_create_document(doc)
      request_namespaces(doc)
    end
    def on_response_document(doc)
      response_namespaces(doc)
    end

    def login(username, password)
      xml = invoke('n2:AuthRequest') do |message|
        Builder.auth(message, username, password)
      end
      Parser.auth_token(xml)
    end

    class Builder
      class << self
        def auth(message, username, password)
          message.add 'name', username
          message.add 'password', password
        end
      end
    end
    class Parser
      class << self
        def auth_token(response)
          auth_token = (response/'//n2:authToken').to_s
          lifetime = (response/'//n2:lifetime').to_i
          
          Zimbra::AuthToken.new(token: auth_token, lifetime: lifetime)
        end
      end
    end
  end
end
