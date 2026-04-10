# frozen_string_literal: true

class SchoolDatatable < AjaxDatatablesRails::ActiveRecord
  include Rails.application.routes.url_helpers

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
        name: name_link(record),
        location: record.location,
        country: record.country,
        website: website_link(record),
        teachers_count: record.teachers_count,
        grade_level: record.display_grade_level,
        actions: action_links(record),
        DT_RowId: record.id
      }
    end
  end

  def get_raw_records
    School.all
  end

  private

  SEARCHABLE_COLUMNS = %w[name city state country website].freeze

  def filter_records(records)
    search_value = params.dig(:search, :value).presence
    return records unless search_value

    conditions = SEARCHABLE_COLUMNS.map { |col| "schools.#{col} ILIKE :q" }.join(" OR ")
    records.where(conditions, q: "%#{search_value}%")
  end

  def name_link(record)
    "<a href=\"#{school_path(record)}\">#{ERB::Util.html_escape(record.name)}</a>".html_safe
  end

  def website_link(record)
    url = record.website
    display = url.to_s.truncate(30)
    "<a href=\"#{ERB::Util.html_escape(url)}\" target=\"_blank\">#{ERB::Util.html_escape(display)}</a>".html_safe
  end

  def action_links(record)
    edit = "<a class=\"btn btn-info\" href=\"#{edit_school_path(record)}\">Edit</a>"
    delete = "<a class=\"btn btn-outline-danger\" data-confirm=\"Are you sure?\" rel=\"nofollow\" data-method=\"delete\" href=\"#{school_path(record)}\">❌</a>"
    "<span class=\"btn-group\">#{edit} #{delete}</span>".html_safe
  end
end
