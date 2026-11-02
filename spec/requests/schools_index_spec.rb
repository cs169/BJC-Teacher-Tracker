# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin schools index", type: :request do
  fixtures :all

  let(:admin) { teachers(:admin) }
  let(:teacher) { teachers(:validated_teacher) }
  let(:column_names) { %w[name location country website teachers_count grade_level actions] }

  def datatable_params(search: "", order: { "0" => { column: "0", dir: "asc" } }, **extra)
    columns = column_names.each_with_index.to_h do |name, index|
      [index.to_s, { data: name, searchable: "true", orderable: "true", search: { value: "", regex: "false" } }]
    end
    { draw: "1", start: "0", length: "100", search: { value: search, regex: "false" },
      columns:, order: }.merge(extra)
  end

  def fetch_schools(**options)
    get schools_path(format: :json), params: datatable_params(**options)
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  def create_school(**attrs)
    school = schools(:berkeley).dup
    school.assign_attributes(attrs)
    school.save!(validate: false)
    school
  end

  describe "access control" do
    it "redirects logged-out users from the JSON endpoint" do
      get schools_path(format: :json), params: datatable_params
      expect(response).to redirect_to(login_path)
    end

    it "redirects non-admin teachers from the JSON endpoint" do
      log_in(teacher)
      get schools_path(format: :json), params: datatable_params
      expect(response).to redirect_to(root_path)
    end

    it "redirects logged-out users from the CSV export" do
      get schools_path(format: :csv)
      expect(response).to redirect_to(login_path)
    end

    it "redirects non-admin teachers from the CSV export" do
      log_in(teacher)
      get schools_path(format: :csv)
      expect(response).to redirect_to(root_path)
    end
  end

  context "as an admin" do
    before { log_in(admin) }

    it "escapes HTML in school names" do
      create_school(name: "<img src=x onerror=alert(1)>")
      body = fetch_schools(search: "onerror")
      expect(body["recordsFiltered"]).to eq 1
      name_cell = body["data"].first["name"]
      expect(name_cell).not_to include("<img")
      expect(name_cell).to include("&lt;img src=x onerror=alert(1)&gt;")
    end

    it "does not link javascript: websites" do
      create_school(name: "Evil School", website: "javascript:alert(1)//\nhttp://x.y")
      body = fetch_schools(search: "Evil")
      website_cell = body["data"].first["website"]
      expect(website_cell).not_to include("href")
      expect(website_cell).not_to include("<a")
    end

    it "links http(s) websites with rel=noopener" do
      body = fetch_schools(search: "UC Berkeley")
      website_cell = body["data"].first["website"]
      expect(website_cell).to include('href="https://berkeley.edu"')
      expect(website_cell).to include('rel="noopener noreferrer"')
    end

    it "matches every term of a multi-word search across columns" do
      body = fetch_schools(search: "Berkeley CA")
      expect(body["data"].map { |row| row["DT_RowId"] }).to eq [schools(:berkeley).id.to_s]
    end

    it "treats _ and % in search literally" do
      underscored = create_school(name: "Under_score Academy")
      expect(fetch_schools(search: "_")["data"].map { |row| row["DT_RowId"] }).to eq [underscored.id.to_s]
      expect(fetch_schools(search: "%")["recordsFiltered"]).to eq 0
    end

    it "returns all schools with an empty search" do
      body = fetch_schools
      expect(body["recordsTotal"]).to eq School.count
      expect(body["recordsFiltered"]).to eq School.count
    end

    it "tolerates a missing order direction" do
      body = fetch_schools(order: { "0" => { column: "0" } })
      expect(body["recordsFiltered"]).to eq School.count
    end

    it "tolerates a negative start and length" do
      get schools_path(format: :json), params: datatable_params.merge(start: "-5", length: "-10")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].length).to eq School.count
    end

    it "tolerates malformed columns and order params" do
      get schools_path(format: :json), params: datatable_params.merge(columns: "x", order: "y", search: "z")
      expect(response).to have_http_status(:ok)
    end

    it "exports all schools as CSV" do
      create_school(name: "Third School")
      get schools_path(format: :csv)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "text/csv"
      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to eq ["Name", "Location", "Country", "Website", "Teachers", "Grade Level"]
      expect(csv.map { |row| row["Name"] }).to match_array(School.pluck(:name))
    end

    it "links to the full CSV export from the index page" do
      get schools_path
      expect(response.body).to include(schools_path(format: :csv))
    end
  end
end
