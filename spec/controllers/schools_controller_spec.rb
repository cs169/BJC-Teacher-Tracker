# frozen_string_literal: true

require "rails_helper"

# This file contains both a <type: :request> and <type: :controller>
RSpec.describe SchoolsController, type: :request do
  fixtures :all

  let(:admin_teacher) { teachers(:admin) }

  before(:all) do
    @create_school_name = "University of California, Berkeley"
    @fail_flash_error_text = "An error occurred: "
    @success_flash_alert = Regexp.new("Created #{@create_school_name} successfully.")
  end

  context "for a regular teacher" do
    it "denies teacher to create" do
      expect(School.find_by(name: @create_school_name)).to be_nil
      post schools_path, params: {
          school: {
              name: @create_school_name,
              city: "Berkeley",
              state: "CA",
              website: "www.berkeley.edu",
              school_type: "public",
              grade_level: "university",
              tags: [],
              nces_id: 123456789000
          }
      }
      expect(School.find_by(name: @create_school_name)).to be_nil
    end
  end

  context "for an admin" do
    before do
      log_in(admin_teacher)
    end

    it "allows admin to create" do
      expect(School.find_by(name: @create_school_name)).to be_nil
      post schools_path, params: {
          school: {
              name: @create_school_name,
              city: "Berkeley",
              country: "US",
              state: "CA",
              website: "www.berkeley.edu",
              school_type: "public",
              grade_level: "university",
              tags: [],
              nces_id: 123456789000
          }
      }
      expect(School.find_by(name: @create_school_name)).not_to be_nil
      expect(@success_flash_alert).to match flash[:success]
    end

    it "requires all fields filled" do
      expect(School.find_by(name: @create_school_name)).to be_nil
      post schools_path, params: {
        school: {
          name: @create_school_name,
          # missing city
          country: "US",
          state: "CA",
          website: "www.berkeley.edu",
          school_type: "public",
          grade_level: "university",
          tags: [],
          nces_id: 123456789000
        }
      }
      expect(School.find_by(name: @create_school_name)).to be_nil
      error = @fail_flash_error_text + "City can't be blank"
      expect(flash[:alert]).to match error

      post schools_path, params: {
        school: {
            name: @create_school_name,
            country: "US",
            city: "Berkeley",
            state: "CA",
            # missing website
            school_type: "public",
            grade_level: "university",
            tags: [],
            nces_id: 123456789000
        }
      }
      expect(School.find_by(name: @create_school_name)).to be_nil
      error = @fail_flash_error_text + "Website can't be blank, Website is invalid"
      expect(flash[:alert]).to match error

      post schools_path, params: {
        school: {
          # missing name
          country: "US",
          city: "Berkeley",
          state: "CA",
          website: "www.berkeley.edu",
          school_type: "public",
          grade_level: "university",
          tags: [],
          nces_id: 123456789000
        }
      }
      expect(School.find_by(name: @create_school_name)).to be_nil
      error = @fail_flash_error_text + "Name can't be blank"
      expect(flash[:alert]).to match error
    end

    it "requires proper inputs for fields" do
      expect(School.find_by(name: @create_school_name)).to be_nil
      # Incorrect state (not chosen from enum list)
      post schools_path, params: {
        school: {
          name: @create_school_name,
          country: "US",
          city: "Berkeley",
          state: "DISTRESS",
          website: "www.berkeley.edu",
          school_type: "public",
          grade_level: "university",
          tags: [],
          nces_id: 123456789000
        }
      }
      expect(School.find_by(name: @create_school_name)).to be_nil
      error = @fail_flash_error_text + "State is not included in the list"
      expect(flash[:alert]).to match error

      post schools_path, params: {
        school: {
          name: @create_school_name,
          country: "US",
          city: "Berkeley",
          state: "CA",
          website: "wwwberkeleyedu",
          school_type: "public",
          grade_level: "university",
          tags: [],
          nces_id: 123456789000
        }
      }
      expect(School.find_by(name: @create_school_name)).to be_nil
      error = @fail_flash_error_text + "Website is invalid"
      expect(flash[:alert]).to match error

      # Incorrect school type
      expect { post schools_path, params: {
        school: {
            name: @create_school_name,
            country: "US",
            city: "Berkeley",
            state: "CA",
            website: "www.berkeley.edu",
            school_type: -1,
            grade_level: "university",
            tags: [],
            nces_id: 123456789000
        }
    }
      }.to raise_error(ArgumentError)
      expect(School.find_by(name: @create_school_name)).to be_nil

      # Incorrect grade_level
      expect { post schools_path, {
              params: {
                  school: {
                      name: @create_school_name,
                      country: "US",
                      city: "Berkeley",
                      state: "CA",
                      website: "www.berkeley.edu",
                      school_type: "public",
                      grade_level: -4,
                      tags: [],
                      nces_id: 123456789000
                  }
              }
          }
      }.to raise_error(ArgumentError)
      expect(School.find_by(name: @create_school_name)).to be_nil
    end

    it "does not allow invalid country" do
      post schools_path, params: {
        school: {
          name: @create_school_name,
          city: "Test City",
          country: "XX", # invalid country
          state: "CA",
          website: "www.berkeley.edu",
          school_type: "public",
          grade_level: "university",
          tags: [],
          nces_id: 123456789000
        }
      }
      expect(School.find_by(name: @create_school_name)).to be_nil
      error = @fail_flash_error_text + "Country XX is not a valid country"
      expect(flash[:alert]).to match error
    end

    it "allows any state when country is not US" do
      post schools_path, params: {
        school: {
          name: @create_school_name,
          city: "Ottawa",
          country: "CA", # Canada
          state: "Ontario",
          website: "www.berkeley.edu",
          school_type: "public",
          grade_level: "university",
          tags: [],
          nces_id: 123456789000
        }
      }
      expect(School.find_by(name: @create_school_name)).not_to be_nil
      expect(@success_flash_alert).to match flash[:success]
    end

    it "does not create duplicate schools in the same city" do
      expect(School.where(name: @create_school_name).count).to eq 0

      post schools_path, params: {
        school: {
          name: @create_school_name,
          country: "US",
          city: "Berkeley",
          state: "CA",
          website: "www.berkeley.edu",
          school_type: "public",
          grade_level: "middle_school",
        }
      }
      expect(School.where(name: @create_school_name).count).to eq 1

      post schools_path, params: {
        school: {
          name: @create_school_name,
          country: "US",
          city: "Berkeley",
          state: "CA",
          website: "www.berkeley.edu",
          school_type: "public",
          grade_level: "university",
        }
      }
      expect(School.where(name: @create_school_name).count).to eq 1
    end
  end
end

RSpec.describe SchoolsController, type: :controller do
  let(:school) { double("School", id: 1, name: "Test School") }

  before do
    allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
    allow(School).to receive(:find).with("1").and_return(school)
  end

  describe "GET #index" do
    let(:dt_columns) do
      {
        "0" => { data: "name", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "1" => { data: "location", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "2" => { data: "country", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "3" => { data: "website", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "4" => { data: "teachers_count", searchable: "false", orderable: "true", search: { value: "", regex: "false" } },
        "5" => { data: "grade_level", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "6" => { data: "actions", searchable: "false", orderable: "false", search: { value: "", regex: "false" } }
      }
    end

    it "renders the index template for HTML requests" do
      get :index
      expect(response).to render_template("index")
    end

    it "returns JSON with datatable keys" do
      get :index, format: :json, params: { draw: "1", start: "0", length: "10", columns: dt_columns }
      expect(response.content_type).to include("application/json")
      body = JSON.parse(response.body)
      expect(body).to have_key("recordsTotal")
      expect(body).to have_key("recordsFiltered")
      expect(body).to have_key("data")
    end

    it "paginates results via length param" do
      get :index, format: :json, params: { draw: "1", start: "0", length: "1", columns: dt_columns }
      body = JSON.parse(response.body)
      expect(body["data"].length).to be <= 1
    end

    it "filters results by search value" do
      get :index, format: :json, params: { draw: "1", start: "0", length: "10",
        columns: dt_columns, search: { value: "nonexistent_school_xyz", regex: "false" } }
      body = JSON.parse(response.body)
      expect(body["recordsFiltered"]).to eq(0)
      expect(body["data"]).to be_empty
    end

    it "returns all schools when no search is applied" do
      get :index, format: :json, params: { draw: "1", start: "0", length: "100",
        columns: dt_columns, search: { value: "", regex: "false" } }
      body = JSON.parse(response.body)
      expect(body["recordsTotal"]).to eq(School.count)
    end

    it "includes expected fields in each data record" do
      get :index, format: :json, params: { draw: "1", start: "0", length: "10", columns: dt_columns }
      body = JSON.parse(response.body)
      if body["data"].any?
        record = body["data"].first
        %w[name location country website teachers_count grade_level actions].each do |key|
          expect(record).to have_key(key)
        end
      end
    end
  end

  describe "GET #show" do
    it "assigns the requested school to @school" do
      get :show, params: { id: 1 }
      expect(assigns(:school)).to eq(school)
      expect(response).to render_template("show")
    end
  end

  describe "GET #new" do
    it "creates a new school and renders new" do
      allow(School).to receive(:new).and_return(school)
      get :new
      expect(assigns(:school)).to eq(school)
      expect(response).to render_template("new")
    end
  end

  describe "GET #edit" do
    it "finds the school and renders edit" do
      get :edit, params: { id: 1 }
      expect(assigns(:school)).to eq(school)
      expect(response).to render_template("edit")
    end
  end

  describe "DELETE #destroy" do
    it "succeeds with no teacher left in the school" do
      allow(school).to receive(:teachers_count).and_return(0)
      allow(school).to receive(:destroy).and_return(nil)
      get :destroy, params: { id: 1 }
      expect(flash[:notice]).to be_present
      expect(response).to redirect_to(schools_path)
    end

    it "fails with teachers still in the school" do
      allow(school).to receive(:teachers_count).and_return(1)
      get :destroy, params: { id: 1 }
      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(schools_path(school))
    end
  end

  describe "PUT #update" do
    before do
      allow(school).to receive(:assign_attributes).and_return(nil)
    end

    it "updates the school and redirects to the schools" do
      allow(school).to receive(:save).and_return(true)
      new_school_name = "New School Name"
      put :update, params: { id: school.id, school: { name: new_school_name } }
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(school_path(school))
    end

    it "does not update the school and re-renders the edit page with error" do
      allow(school).to receive(:save).and_return(false)
      allow(school).to receive_message_chain(:errors, :full_messages).and_return(["Name can't be blank"])
      put :update, params: { id: school.id, school: { name: nil } }
      expect(flash[:alert]).to be_present
      expect(response).to render_template("edit")
    end
  end
end
