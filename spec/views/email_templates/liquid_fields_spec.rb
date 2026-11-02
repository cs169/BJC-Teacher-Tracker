# frozen_string_literal: true

require "rails_helper"

RSpec.describe "email_templates/_liquid_fields.erb", type: :view do
  it "includes the teacher URL tags in the allowed tags list" do
    allow(view).to receive(:current_user).and_return(
      double(email_attributes: { teacher_first_name: "Test" })
    )

    render partial: "email_templates/liquid_fields"

    expect(rendered).to include("{{view_teacher_url}}")
    expect(rendered).to include("Admin-only")
    expect(rendered).to include("{{edit_teacher_url}}")
  end
end
