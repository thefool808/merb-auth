module MerbfulAuthentication
  module Adapter
    module Common
      
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.send(:extend,  ClassMethods)
      end
      
      
      module InstanceMethods
        
        # Encrypts the password with the user salt
        def encrypt(password)
          self.class.encrypt(password, salt)
        end
        
        def encrypt_password
          return if password.blank?
          self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
          self.crypted_password = encrypt(password)
        end
        
        def authenticated?(password)
          crypted_password == encrypt(password)
        end
        
        def password_required?
          crypted_password.blank? || !password.blank?
        end
        
        def activate
          @activated = true
          self.activated_at = Time.now.utc
          self.activation_code = nil
          save
          # send mail for activation
          send_activation_notification
        end
        
        # Returns true if the user has just been activated.
        def recently_activated?
          @activated
        end

        def activated?
         return false if self.new_record?
         !! activation_code.nil?
        end
        
        def set_login
          return nil unless self.login.nil?
          return nil if self.email.nil?
          logn = self.email.split("@").first
          # Check that that login is not taken
          taken_logins = self.class.find_all_with_login_like("#{logn}%").map{|u| u.login}
          if taken_logins.empty?
            self.login = logn
          else
            taken_logins.first =~ /(\d*)$/
            if $1.blank?
              self.login = "#{logn}000"
            else
              self.login ="#{logn}#{$1.succ}"
            end
          end
        end
        
        def make_activation_code
          self.activation_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
        end
        
        def remember_token?
          remember_token_expires_at && DateTime.now < DateTime.parse(remember_token_expires_at.to_s)
        end

        def remember_me_until(time)
          self.remember_token_expires_at = time
          self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
          save
        end

        def remember_me_for(time)
          remember_me_until (DateTime.now + time)
        end

        # These create and unset the fields required for remembering users between browser closes
        # Default of 2 weeks 
        def remember_me
          remember_me_for (Merb::Const::WEEK * 2)
        end

        def forget_me
          self.remember_token_expires_at = nil
          self.remember_token            = nil
          self.save
        end
        
        
      end
      
      module ClassMethods
        
        # Encrypts some data with the salt.
        def encrypt(password, salt)
          Digest::SHA1.hexdigest("--#{salt}--#{password}--")
        end
        
        # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
        def authenticate(email, password)
          u = find_active_with_conditions(:email => email)
          u && u.authenticated?(password) ? u : nil
        end
        
      end
      
    end
  end
end