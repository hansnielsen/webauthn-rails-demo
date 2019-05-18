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

    challenge = session.delete(:reg_challenge)
    credential = WebAuthn::Credential.from_create(response)

    begin
      credential.verify(challenge)
    rescue WebAuthn::Error => e
      flash[:error] = "Unable to register: #{e.class.name}"
      redirect_to action: "new"
      return
    end

    key_handle = credential.id
    name = "WebAuthn key handle #{key_handle[0...20]}..."
    public_key = credential.public_key
    counter = credential.sign_count
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
    credential = WebAuthn::Credential.from_get(response)
    registration = Registration.find_by_key_handle(credential.id)

    if registration.nil?
      flash[:error] = "Key not registered or invalid key"
      redirect_to action: "index"
      return
    end

    rp_id = registration.u2f? ? Rails.configuration.app_id : nil

    challenge = session.delete(:challenge)
    begin
      # We can't use PublicKeyCredential#verify because it doesn't
      # support passing an RP ID, so we call verify on the underlying
      # AuthenticatorAssertionResponse instead.
      enc = WebAuthn.configuration.encoder
      credential.response.verify(
        enc.decode(challenge),
        sign_count: registration.counter,
        public_key: enc.decode(registration.public_key),
        rp_id: rp_id,
      )

      registration.update(counter: credential.sign_count)
    rescue WebAuthn::SignCountVerificationError => e
      flash[:error] = "Credential replay detected!"
      redirect_to action: "index"
      return
    rescue WebAuthn::Error => e
      flash[:error] = "Unable to authenticate: #{e.class.name}"
      redirect_to action: "index"
      return
    end

    flash[:success] = "Validated response from key #{registration.id}"
    redirect_to action: "index"
  end
end
