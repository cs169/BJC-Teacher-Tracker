# frozen_string_literal: true

module SchoolParams
  private
  def unique_school_params
    {
      name: school_params[:name],
      country: school_params[:country],
      city: school_params[:city],
      state: school_params[:state]
    }
  end

  def school_params
    params.require(:school).permit(:name, :country, :city, :state, :website, :grade_level, :school_type, { tags: [] }, :nces_id)
  end
end
