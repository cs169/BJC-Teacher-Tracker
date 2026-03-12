# frozen_string_literal: true

class SchoolDatatable < AjaxDatatablesRails::ActiveRecord
  include Rails.application.routes.url_helpers

  def view_columns
    @view_columns ||= {
      name: { source: "School.name" },
      location: { source: "School.city" },
      country: { source: "School.country" },
      website: { source: "School.website" },
      teachers_count: { source: "School.teachers_count", searchable: false },
      grade_level: { source: "School.grade_level" },
      actions: { source: "School.id", searchable: false, orderable: false }
    }
  end

  def data
    records.map do |school|
      {
        name: "<a href=\"#{school_path(school)}\">#{ERB::Util.html_escape(school.name)}</a>",
        location: ERB::Util.html_escape(school.location),
        country: ERB::Util.html_escape(school.country),
        website: "<a href=\"#{ERB::Util.html_escape(school.website)}\" target=\"_blank\">#{ERB::Util.html_escape(school.website.truncate(30))}</a>",
        teachers_count: school.teachers_count,
        grade_level: ERB::Util.html_escape(school.display_grade_level),
        actions: "<span class=\"btn-group\">" \
                 "<a class=\"btn btn-info\" href=\"#{edit_school_path(school)}\">Edit</a>" \
                 "<a class=\"btn btn-outline-danger\" data-confirm=\"Are you sure?\" rel=\"nofollow\" data-method=\"delete\" href=\"#{school_path(school)}\">&#10060;</a>" \
                 "</span>"
      }
    end
  end

  def get_raw_records
    School.all
  end
end
