require 'openid'
require 'openid/extensions/sreg'
require 'openid/extensions/ax'
require 'openid/extensions/pape'

# more fields can be found at http://www.axschema.org/types/

class OpenIDFields

  SREG_REQUIRED_FIELDS = []
    AX_REQUIRED_FIELDS = []
  # For demo instances we are going to require all data as optional
  SREG_OPTIONAL_FIELDS = [
    :nickname,
    :email,
    :fullname,
    :dob,
   :gender,
   :postcode,
   :country,
   :language,
   :timezone
  ]
  AX_OPTIONAL_FIELDS = [
          "http://axschema.org/namePerson/friendly",
          "http://axschema.org/contact/email",
          "http://axschema.org/namePerson",
          "http://axschema.org/birthDate",
          "http://axschema.org/person/gender",
          "http://axschema.org/contact/postalCode/home",
          "http://axschema.org/contact/country/home",
          "http://axschema.org/pref/language",
          "http://axschema.org/pref/timezone"
  ]
  
  def self.add_simple_registration_fields(open_id_request)
    sreg_request = OpenID::SReg::Request.new

    # filter out AX identifiers (URIs)
    required_fields = SREG_REQUIRED_FIELDS.collect { |f| f.to_s unless f =~ /^https?:\/\// }.compact
    optional_fields = SREG_OPTIONAL_FIELDS.collect { |f| f.to_s unless f =~ /^https?:\/\// }.compact

    sreg_request.request_fields(required_fields, true) unless required_fields.blank?
    sreg_request.request_fields(optional_fields, false) unless optional_fields.blank?
    # sreg_request.policy_url = FIELDS[:policy_url] if FIELDS[:policy_url]
    open_id_request.add_extension(sreg_request)
  end

  def self.add_ax_fields(open_id_request)
    ax_request = OpenID::AX::FetchRequest.new

    # look through the :required and :optional fields for URIs (AX identifiers)
    AX_REQUIRED_FIELDS.each do |f|
      next unless f =~ /^https?:\/\//
      ax_request.add( OpenID::AX::AttrInfo.new( f, nil, true ) )
    end

    AX_OPTIONAL_FIELDS.each do |f|
      next unless f =~ /^https?:\/\//
      ax_request.add( OpenID::AX::AttrInfo.new( f, nil, false ) )
    end

    open_id_request.add_extension( ax_request )
  end

  def self.get_profile_data(profile_data)
    ret = {}
    fields = SREG_REQUIRED_FIELDS  | SREG_OPTIONAL_FIELDS
    keys = { }

    { AX_REQUIRED_FIELDS => SREG_REQUIRED_FIELDS, AX_OPTIONAL_FIELDS => SREG_OPTIONAL_FIELDS }.each do |arr, key_arr|
      if !arr.empty? && !key_arr.empty?
        0.upto(arr.count - 1) do |i|
          key = key_arr[i]
          val = arr[i]
          # warn "#{key}: #{val}"
          keys[key] = val
        end
      end
    end

    # SReg
    fields.each do |k|
      key = k.to_s
      value = profile_data[key]
      value = value.first if value.is_a?(Array)
      ret[k] = value if !value.blank?
    end

    # AX
    keys.each do |k, v|
      key = v.to_s
      value = profile_data[key]
      value = value.first if value.is_a?(Array)
      ret[k] = value if !value.blank?
    end

    return ret
  end

  def self.add_pape(oidreq)
      papereq = OpenID::PAPE::Request.new
      papereq.add_policy_uri(OpenID::PAPE::AUTH_PHISHING_RESISTANT)
      papereq.max_auth_age = 2*60*60
      oidreq.add_extension(papereq)
  end
end