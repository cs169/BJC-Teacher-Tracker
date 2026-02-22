# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeachersController, type: :controller do
  fixtures :all

  it "rejects invalid signup information" do
    previous_count = Teacher.count
    post :create, params: {
      school: {
        name: "invalid",
        city: "Berkeley",
        state: "CA",
        website: "invalid.com"
      },
      teacher: {
        first_name: "",
        last_name: "invalid",
        email: "invalid@invalid.edu",
        status: "invalid",
        snap: "invalid"
      }
    }
    expect(Teacher.count).to eq(previous_count)
    expect(/An error occurred/).to match(flash[:alert])
  end

  it "rejects invalid signup school information" do
    previous_count = Teacher.count
    post :create, params: {
      school: {
        city: "Berkeley",
        state: "CA",
      },
      teacher: {
        first_name: "invalid",
        last_name: "invalid",
        email: "invalid@invalid.edu",
        status: "invalid",
        snap: "invalid"
      }
    }
    expect(Teacher.count).to eq(previous_count)
    expect(flash[:alert]).to match(/An error occurred/)
  end

  it "accepts valid signup information" do
    previous_count = Teacher.count
    post :create, params: {
      school: {
        name: "valid_example",
        country: "US",
        city: "Berkeley",
        state: "CA",
        website: "valid_example.com",
        school_type: "Public",
        grade_level: "High School"
      },
      teacher: {
        first_name: "valid_example",
        last_name: "valid_example",
        status: 0,
        snap: "valid_example"
      },
      email: {
        primary: "valid_example@validexample.edu",
      }
    }
    expect(Teacher.count).to eq(previous_count + 1)
    assert_match(/Thanks for signing up for BJC/, flash[:success])
  end

  it "redirects existing users to the login page" do
    post :create, params: {
      school: {
        id: 1
      },
      teacher: Teacher.first.attributes,
      email: {
        primary: EmailAddress.find_by(teacher_id: Teacher.first.id).email
      }
    }
    expect(response).to redirect_to(login_path)
    expect(flash[:notice]).to match(/Please log in/)
  end
end
