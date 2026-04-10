# frozen_string_literal: true

class SchoolDatatable < AjaxDatatablesRails::ActiveRecord
  def view_columns
    @view_columns ||= {
      name: { source: "School.name", cond: :like },
      location: { source: "School.city", cond: :like },
      country: { source: "School.country", cond: :like },
      website: { source: "School.website", cond: :like },
      teachers_count: { source: "School.teachers_count", searchable: false },
      grade_level: { source: "School.grade_level", searchable: false },
      actions: { source: "School.id", searchable: false, orderable: false }
    }
  end

  def data
    records.map do |record|
      {
        name: record.name,
        location: record.location,
        country: record.country,
        website: record.website,
        teachers_count: record.teachers_count,
        grade_level: record.display_grade_level,
        DT_RowId: record.id
      }
    end
  end

  def get_raw_records
    School.all
  end
end
