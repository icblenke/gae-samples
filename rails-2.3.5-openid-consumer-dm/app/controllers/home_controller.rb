require "openid"

class HomeController < ApplicationController

  def index

  end

  def openid_start
    begin
      identifier = params[:openid_identifier]

      # make sure we have selected an OpenID provider
      if identifier.blank?
        flash[:warning] = "Please select your OpenID provider."
        redirect_to login_url
        return
      end

      oidreq = consumer.begin(identifier)
    rescue OpenID::OpenIDError => e
      # Network discovery failed (propably)
      flash[:warning] = "You selected an invalid OpenID provider. Please try again."
      redirect_to login_url
      return
    end

    # Add fields to request (we are requesting all available fields for testing purposes)
    OpenIDFields.add_simple_registration_fields(oidreq)
    OpenIDFields.add_ax_fields(oidreq)
    OpenIDFields.add_pape(oidreq)

    return_to = openid_stop_url
    realm = root_url

    # Send redirect based on our immediate mode selection
    immediate = false
    if oidreq.send_redirect?(realm, return_to, immediate)
      redirect_to oidreq.redirect_url(realm, return_to, immediate)
    else
      render :text => oidreq.html_markup(realm, return_to, immediate, {'id' => 'openid_form'})
    end
  end

  def openid_stop
    current_url = openid_stop_url
    oidresp = consumer.complete(request.query_parameters, current_url)

    case oidresp.status
      when OpenID::Consumer::SUCCESS
        profile_data = {}

        [ OpenID::SReg::Response, OpenID::AX::FetchResponse ].each do |data_response|
          if data_response.from_success_response( oidresp )
            profile_data.merge! data_response.from_success_response( oidresp ).data
          end
        end

        # verification was succesful
        flash[:notice] = "You were succesfully authenticated."

        # gather the profile data
        @profile_data = OpenIDFields.get_profile_data(profile_data)

        # add the identity_url and the display_identifier to the profile data for inspection
        @profile_data[:identity_url] = oidresp.identity_url
        @profile_data[:display_identifier] = oidresp.identity_url

        # redirect the user
        redirect_to index_url
      when OpenID::Consumer::CANCEL
        flash[:warning] = "The login process was cancelled by the user."
        redirect_to index_url
      else
        flash[:warning] = "You could not be authenticated."
        redirect_to index_url
    end
  end

private

    def consumer
      if @consumer.nil?
        store = GaeStore.new
        @consumer = OpenID::Consumer.new(session, store)
      end
      return @consumer
    end
  
end