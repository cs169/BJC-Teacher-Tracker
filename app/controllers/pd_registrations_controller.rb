# frozen_string_literal: true

class PdRegistrationsController < ApplicationController
  before_action :require_login
  before_action :require_admin
  before_action :set_pd_registration, only: [:show, :edit, :update, :destroy]
  before_action :set_professional_development, only: [:new, :create, :edit, :update, :destroy]

  def index
  end

  def show
  end

  def new
    @pd_registration = PdRegistration.new
  end

  def edit
  end

  def create
    @pd_registration = PdRegistration.new(pd_registration_params.merge(
      professional_development_id: @professional_development.id))

    if @pd_registration.save
      redirect_to professional_development_path(@professional_development),
                  notice: "Registration for professional development was successfully created."
    else
      flash.now[:alert] = @pd_registration.errors.full_messages.to_sentence
      render "professional_developments/show"
    end
  end

  def update
    if @pd_registration.update(pd_registration_params)
      redirect_to professional_development_path(@professional_development),
                  notice: "Registration was successfully updated."
    else
      flash.now[:alert] = @pd_registration.errors.full_messages.to_sentence
      render "professional_developments/show"
    end
  end

  def destroy
    if @pd_registration.destroy
      redirect_to professional_development_path(@professional_development),
                  notice: "Registration was successfully cancelled."
    else
      flash.now[:alert] = @pd_registration.errors.full_messages.to_sentence
      render "professional_developments/show"
    end
  end

  private
  def set_pd_registration
    @pd_registration = PdRegistration.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to professional_development_path, alert: "Registration not found."
  end

  def set_professional_development
    @professional_development = ProfessionalDevelopment.find_by(id: params[:professional_development_id])
    unless @professional_development
      redirect_to professional_developments_path, alert: "Professional Development not found."
    end
  end

  # professional_development_id is deliberately not permitted: it always comes
  # from the nested route (see create's merge), so a registration cannot be
  # moved to another professional development through the params.
  def pd_registration_params
    params.require(:pd_registration).permit(:teacher_id, :attended, :role)
  end
end
