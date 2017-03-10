module Zimbra
  class Contact
    ATTRS = [
      :id, :revision, :folder_id, :date, :first_name, :last_name, :email, :phone_number, 
      :birthday, :notes, :street, :city, :state, :postal_code, :file_as, :image
    ] unless const_defined?(:ATTRS)

    ATTRIBUTE_MAPPING = {
      :id => :id,
      :rev => :revision,
      :l => :folder_id,
      :d => :date,
      :firstName => :first_name,
      :lastName => :last_name,
      :email => :email,
      :mobilePhone => :phone_number,
      :bday => :birthday,
      :notes => :notes,
      :homeStreet => :street,
      :homeCity => :city,
      :homeState => :state,
      :homePostalCode => :postal_code,
      :fileAs => :file_as,
      :image => :image
    }

    attr_accessor *ATTRS

    class << self
      def find_by_id(contact_id)
        ContactService.find(contact_id)
      end

      def find_by_phone_number(phone_number)
        ContactService.find_by_phone_number(phone_number)
      end

      def find_by_email(email)
        ContactService.find_by_email(email)
      end

      def all
        ContactService.all
      end

      def delete(id)
        ContactService.delete(id)
      end

      def new_from_zimbra_attributes(zimbra_attributes)
        new(parse_zimbra_attributes(zimbra_attributes))
      end
      
      def parse_zimbra_attributes(zimbra_attributes)
        zimbra_attributes = Zimbra::Hash.symbolize_keys(zimbra_attributes.dup, true)
        
        return {} unless zimbra_attributes.has_key?(:cn) && zimbra_attributes[:cn].has_key?(:attributes)

        contact_attributes = {}

        zimbra_attributes.dig(:cn, :attributes).each do |attr|
          key = ATTRIBUTE_MAPPING[attr.first]
          contact_attributes[key] = attr.last if key
        end

        zimbra_attributes.dig(:cn, :a).each do |a|
          key = ATTRIBUTE_MAPPING[a.dig(:attributes, :n).to_sym]
          contact_attributes[key] = a.dig('value') if key
        end

        contact_attributes
      end
    end

    def initialize(args = {})
      self.attributes = args
    end

    def attributes=(args = {})
      ATTRS.each do |attr_name|
        if args.has_key?(attr_name)
          self.send(:"#{attr_name}=", args[attr_name])
        elsif args.has_key?(attr_name.to_s)
          self.send(:"#{attr_name}=", args[attr_name.to_s])
        end
      end
    end

    def save
      if new_record?
        Zimbra::ContactService.create(self)
      else
        Zimbra::ContactService.update(self)
      end
      self
    end
    
    def new_record?
      id.nil?
    end

    def phone_number
      @phone_number.to_s.gsub(/[^\d]/, '')
    end

    def create_xml(document)
      # ContactActionRequest
      # document.add "action" do |action|
      #   action.set_attr "op", "update"
      #   action.set_attr "id", id
      #   Zimbra::A.inject(action, 'firstName', first_name)
      #   Zimbra::A.inject(action, 'lastName', last_name)
      #   Zimbra::A.inject(action, 'email', email)
      #   Zimbra::A.inject(action, 'homePhone', phone_number)
      # end

      document.add "cn" do |cn|
        cn.set_attr "id", id if id
        Zimbra::A.inject(cn, 'firstName', first_name)
        Zimbra::A.inject(cn, 'lastName', last_name)
        Zimbra::A.inject(cn, 'email', email)
        Zimbra::A.inject(cn, 'mobilePhone', phone_number)
        Zimbra::A.inject(cn, 'birthday', birthday)
        Zimbra::A.inject(cn, 'notes', notes)
        Zimbra::A.inject(cn, 'homeStreet', street)
        Zimbra::A.inject(cn, 'homeCity', city)
        Zimbra::A.inject(cn, 'homeState', state)
        Zimbra::A.inject(cn, 'homePostalCode', postal_code)
        Zimbra::A.inject(cn, 'fileAs', file_as)
        # Zimbra::A.inject(cn, 'fileAs', "8:#{full_name}")
        #Zimbra::A.inject(cn, 'image', image, 'ct' => 'application/jpeg', 'filename' => 'profile_photo.jpeg', 'part' => "123456", 'id' => '123456' )

      end

      document
    end

    def delete_xml(document)
      document.add "action" do |mime|
        mime.set_attr "op", "delete"
        mime.set_attr "id", id
      end
    end

  end

  class ContactService < HandsoapAccountService
    def find(contact_id)
      all.detect{ |contact| contact.id == contact_id }
    end

    def find_by_phone_number(phone_number)
      all.select{ |contact| contact.phone_number == phone_number }
    end

    def find_by_email(email)
      all.select{ |contact| contact&.email&.downcase == email.downcase }
    end

    def all
      xml = invoke("n2:GetContactsRequest")
      Parser.get_all_response(xml)
    end

    def create(contact)
      xml = invoke("n2:CreateContactRequest") do |message|
        Builder.create(message, contact)
      end
      response_hash = Zimbra::Hash.from_xml(xml.document.to_s)
      contact.id = response_hash[:Envelope][:Body][:CreateContactResponse][:cn][:attributes][:id]
    end
    
    def update(contact)
      xml = invoke("n2:ModifyContactRequest") do |message|
        Builder.update(message, contact)
      end
    end
    
    def delete(contact_id)
      xml = invoke("n2:ContactActionRequest") do |message|
        Builder.delete(message, contact_id)
      end
    end

    class Builder
      class << self
        def create(message, contact)
          contact.create_xml(message)
        end
        
        def update(message, contact)
          contact.create_xml(message)
        end
        
        def delete(message, contact_id)
          # contact.delete_xml(message)
          message.add "action" do |mime|
            mime.set_attr "op", "delete"
            mime.set_attr "id", contact_id
          end
        end
      end
    end
    
    class Parser
      class << self
        def get_all_response(response)
          (response/"//n2:cn").map do |node|
            contact_response(node)
          end
        end
        
        def contact_response(node)
          Zimbra::Contact.new_from_zimbra_attributes(Zimbra::Hash.from_xml(node.to_xml))
        end

      end
    end
  end
end