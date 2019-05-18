class TwoFactorController < ApplicationController
  def index
    @regs = Registration.all
  end

  def destroy
    r = Registration.find_by_id(params[:id])
    flash[:warning] = "Deleted key #{params[:id]} (#{r.name})"
    r.destroy
    redirect_to action: "index"
  end

  def new
    @options = WebAuthn.credential_creation_options

    # Encode challenge and user ID for JSON
    @options[:challenge] = Base64.urlsafe_encode64(@options[:challenge])
    @options[:user][:id] = Base64.urlsafe_encode64(@options[:user][:id])

    # Fetch existing Registrations to exclude
    @options[:excludeCredentials] = Registration.all.map do |r|
      {
        type: "public-key",
        id: r.key_handle,
      }
    end

    # Store encoded challenge for the verification step
    session[:reg_challenge] = @options[:challenge]
  end

  def create
    response = JSON.parse(params[:response])

    attestation_object = Base64.urlsafe_decode64(response.fetch("attestationObject"))
    client_data_json = Base64.urlsafe_decode64(response.fetch("clientDataJSON"))

    attestation_response = WebAuthn::AuthenticatorAttestationResponse.new(
      attestation_object: attestation_object,
      client_data_json: client_data_json
    )

    challenge = Base64.urlsafe_decode64(session.fetch(:reg_challenge))

    begin
      attestation_response.verify(challenge, request.base_url)
    rescue WebAuthn::VerificationError => e
      flash[:error] = "Unable to register: #{e.class.name}"
      redirect_to action: "new"
      return
    ensure
      session.delete(:raw_challenge)
    end

    key_handle = Base64.urlsafe_encode64(attestation_response.credential.id, padding: false)
    name = "WebAuthn key handle #{key_handle[0...20]}..."
    public_key = Base64.urlsafe_encode64(attestation_response.credential.public_key)
    counter = attestation_response.authenticator_data.sign_count
    reg = Registration.create!(key_handle: key_handle, public_key: public_key, counter: counter, name: name, format: :webauthn)

    flash[:success] = "Successfully registered new key #{reg.id}"
    redirect_to action: "index"
  end

  def sign
    key_handles = Registration.all.map(&:key_handle)
    if key_handles.empty?
      flash[:error] = "No keys registered yet, can't authenticate"
      redirect_to action: "index"
      return
    end

    # Generate WebAuthn assertion request
    req = WebAuthn.credential_request_options
    req[:challenge] = Base64.urlsafe_encode64(req[:challenge])
    req[:allowCredentials] = key_handles.map do |kh|
      { id: kh, type: "public-key" }
    end
    # Needed for U2F compatibility
    if Registration.any?(&:u2f?)
      req[:extensions] = {appid: Rails.configuration.app_id}
    end
    @credential_request_options = req

    # Store challenge. We need it for the verification step
    session[:challenge] = req[:challenge]
  end

  def validate
    response = JSON.parse(params[:response])
    registration = Registration.find_by_key_handle(response.fetch("id"))

    if registration.nil?
      flash[:error] = "Key not registered or invalid key"
      redirect_to action: "index"
      return
    end

    key_handle = Base64.urlsafe_decode64(registration.key_handle)

    auth_response = WebAuthn::AuthenticatorAssertionResponse.new(
      credential_id: key_handle,
      authenticator_data: Base64.urlsafe_decode64(response.fetch("authenticatorData")),
      client_data_json: Base64.urlsafe_decode64(response.fetch("clientDataJSON")),
      signature: Base64.urlsafe_decode64(response.fetch("signature")),
    )

    credential = {
      type: "public-key",
      id: key_handle,
      public_key: Base64.urlsafe_decode64(registration.public_key),
    }

    rp_id = registration.u2f? ? Rails.configuration.app_id : nil
    challenge = Base64.urlsafe_decode64(session.delete(:challenge))
    begin
      auth_response.verify(challenge, request.base_url, allowed_credentials: [credential], rp_id: rp_id)
    rescue WebAuthn::VerificationError => e
      flash[:error] = "Unable to authenticate: #{e.class.name}"
      redirect_to action: "index"
      return
    end

    counter = auth_response.authenticator_data.sign_count
    if registration.counter >= counter
      flash[:error] = "Credential replay detected!"
      redirect_to action: "index"
      return
    end
    registration.update(counter: counter)

    flash[:success] = "Validated response from key #{registration.id}"
    redirect_to action: "index"
  end
end
