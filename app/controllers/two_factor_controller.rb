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
  end

  def create
  end

  def sign
  end

  def validate
  end
end
