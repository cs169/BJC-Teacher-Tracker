# frozen_string_literal: true

class SchoolsController < ApplicationController
  include SchoolParams
  before_action :require_admin

  def index
    @schools = School.all.order(:name)
  end

  def show
    @school = School.find(params[:id])
    @all_schools_except_current = School.where.not(id: @school.id).order(:name)
  end

  def search
    School.search_list
  end

  def create
    @school = School.find_by(**unique_school_params)
    if @school
      @school.assign_attributes(school_params)
    else
      @school = School.new(school_params)
    end
    load_ordered_schools
    if @school.save
      flash[:success] = "Created #{@school.name} successfully."
      redirect_to schools_path
    else
      flash.now[:alert] = "An error occurred: #{@school.errors.full_messages.join(', ')}"
      render "new"
    end
  end

  def new
    @school = School.new
    load_ordered_schools
  end

  def edit
    @school = School.find(params[:id])
  end

  def update
    @school = School.find(params[:id])
    @school.assign_attributes(school_params)
    if @school.save
      flash[:success] = "Updated #{@school.name} successfully."
      redirect_to school_path(@school)
    else
      flash.now[:alert] = "An error occurred: #{@school.errors.full_messages.join(', ')}"
      render "edit"
    end
  end

  def destroy
    @school = School.find(params[:id])
    if @school.teachers_count > 0
      redirect_to schools_path(@school), alert: "Cannot delete a school which still has teachers"
      return
    end
    @school.destroy
    redirect_to schools_path, notice: "Deleted \"#{@school.name}\" successfully."
  end

  private
  def load_ordered_schools
    @ordered_schools ||= School.all.order(:name)
  end
end
