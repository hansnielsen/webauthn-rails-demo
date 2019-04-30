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
  end

  def validate
  end

  private

  def u2f
    @_u2f ||= U2F::U2F.new(Rails.configuration.app_id)
  end
end
