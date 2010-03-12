if defined? JRuby::Rack
  require 'openid'
  require 'openid/store/interface'
  require 'dm-core'
  require 'net/http'
  require 'appengine-apis/urlfetch'

  OpenID::Util.logger = Rails.logger

  # Fetcher class compatible with GAE
  class MyFetcher < OpenID::StandardFetcher
    def fetch(url, body=nil, headers=nil, redirect_limit=REDIRECT_LIMIT)
      raise OpenID::FetchingError, "Blank URL: #{url}" if url.blank?

      headers ||= {}
      headers['User-agent'] ||= USER_AGENT

      options = {
        :follow_redirects => true,
        :allow_truncated => true,
        :headers => headers
      }

      response = nil

      if not body.nil?
        options[:method] = 'POST'
        options[:headers]["Content-type"] ||= "application/x-www-form-urlencoded"
        options[:payload] = body # Rack::Utils.build_query(body)
      else
        options[:method] = 'GET'
      end

      begin
        response = AppEngine::URLFetch.fetch(url, options)
      rescue Exception => why
        raise OpenID::FetchingError, "Error fetching #{url}: #{why}"
      end

      return OpenID::HTTPResponse._from_net_response(response, url)
    end
  end

  OpenID.fetcher = MyFetcher.new

  class MyAssociation
    include DataMapper::Resource

    before :save, :set_expires

    property :id,             Serial
    property :handle,           String
    property :secret,             Blob
    property :issued,             Integer
    property :lifetime,           Integer
    property :assoc_type,     String
    property :srv_url,             String
    property :expires,            Integer

    def from_record
      assoc = OpenID::Association.new(handle, secret, issued, lifetime, assoc_type)
    end

private

    def set_expires
      expires =issued + lifetime
    end
  end

  class MyNonce
    include DataMapper::Resource

    property :id,         Serial
    property :salt,       String,  :required => true
    property :srv_url,    String,  :required => true
    property :timestamp,  Integer, :required => true

  end

  class GaeStore < OpenID::Store::Interface

    # Put a Association object into storage.
    # When implementing a store, don't assume that there are any limitations
    # on the character set of the srv_url.  In particular, expect to see
    # unescaped non-url-safe characters in the srv_url field.
    def store_association(server_url, assoc)
      remove_association(server_url, assoc.handle)
      a = MyAssociation.new(
        :srv_url    => server_url,
        :handle     => assoc.handle,
        :secret     => assoc.secret,
        :issued     => assoc.issued,
        :lifetime   => assoc.lifetime,
        :assoc_type => assoc.assoc_type
      )
      a.save
    end

    # Returns a Association object from storage that matches
    # the srv_url.  Returns nil if no such association is found or if
    # the one matching association is expired. (Is allowed to GC expired
    # associations when found.)
    def get_association(server_url, handle=nil)
      assocs =  if handle.nil?
        MyAssociation.all(:srv_url => server_url)
      else
        MyAssociation.all(:srv_url => server_url, :handle => handle)
      end

      assocs.each do |assoc|
        a = assoc.from_record
        if a.expires_in <= 0
          assoc.destroy!
        else
          return a
        end
      end if assocs.any?

      return nil
    end

    # If there is a matching association, remove it from the store and
    # return true, otherwise return false.
    def remove_association(server_url, handle)
      assocs = MyAssociation.all(:srv_url => server_url, :handle => handle)
      assocs.destroy! if assocs
    end

    # Return true if the nonce has not been used before, and store it
    # for a while to make sure someone doesn't try to use the same value
    # again.  Return false if the nonce has already been used or if the
    # timestamp is not current.
    # You can use OpenID::Store::Nonce::SKEW for your timestamp window.
    # srv_url: URL of the server from which the nonce originated
    # timestamp: time the nonce was created in seconds since unix epoch
    # salt: A random string that makes two nonces issued by a server in
    #       the same second unique
    def use_nonce(server_url, timestamp, salt)
      return false if MyNonce.first(:srv_url => server_url, :timestamp => timestamp, :salt => salt)
      return false if (timestamp - Time.now.to_i).abs > OpenID::Nonce.skew

      n = MyNonce.new(:srv_url => server_url, :timestamp => timestamp, :salt => salt)
      n.save

      return true
    end

    def cleanup_nonces
      now = Time.now.to_i

      nonces = MyNonce.all(:timestamp.gt => now + OpenID::Nonce.skew)
      nonces.destroy! if nonces

      nonces = MyNonce.all(:timestamp.lt => now - OpenID::Nonce.skew).destroy!
      nonces.destroy! if nonces
    end

    def cleanup_associations
      # now = Time.now.to_i
      now = Time.now.to_i

      assocs = MyAssociation.all(:expires.lt => now)
      assocs.destroy! if assocs
    end
  end
end