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

  # Demo code from https://github.com/castle/ruby-u2f
  def new
    # Generate one for each version of U2F, currently only `U2F_V2`
    @registration_requests = u2f.registration_requests

    # Store challenges. We need them for the verification step
    session[:challenges] = @registration_requests.map(&:challenge)

    # Fetch existing Registrations from your db and generate SignRequests
    key_handles = Registration.all.map(&:key_handle)
    @sign_requests = u2f.authentication_requests(key_handles)

    @app_id = u2f.app_id
  end

  # Demo code from https://github.com/castle/ruby-u2f
  def create
    response = U2F::RegisterResponse.load_from_json(params[:response])

    reg = begin
      u2f.register!(session[:challenges], response)
    rescue U2F::Error => e
      flash[:error] = "Unable to register: #{e.class.name}"
      redirect_to action: "new"
      return
    ensure
      session.delete(:challenges)
    end

    # save a reference to your database
    name = "U2F key handle #{reg.key_handle[0...20]}..."
    reg = Registration.create!(key_handle: reg.key_handle, public_key: reg.public_key, counter: reg.counter, name: name)

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
    req[:extensions] = {appid: Rails.configuration.app_id}
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

    challenge = session.delete(:challenge)
    begin
      credential.verify(
        challenge,
        sign_count: registration.counter,
        public_key: registration.public_key,
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

  private

  def u2f
    @_u2f ||= U2F::U2F.new(Rails.configuration.app_id)
  end
end
