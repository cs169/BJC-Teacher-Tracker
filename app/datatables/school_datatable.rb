# frozen_string_literal: true

class SchoolDatatable < AjaxDatatablesRails::ActiveRecord
  include Rails.application.routes.url_helpers

  DEFAULT_PAGE_LENGTH = 100
  MAX_PAGE_LENGTH = 1000

  def initialize(params, options = {})
    super(sanitize_params(params), options)
  end

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
        # DataTables writes cell data as HTML, so every free-text field must be
        # escaped here (city/state/country come from the public signup form).
        location: ERB::Util.html_escape(record.location),
        country: ERB::Util.html_escape(record.country),
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

  TERM_CONDITION = "(#{SEARCHABLE_COLUMNS.map { |col| "schools.#{col} ILIKE :term" }.join(' OR ')})"

  # Each whitespace-separated term must match at least one searchable column,
  # so "Berkeley CA" matches a school in Berkeley, CA.
  def filter_records(records)
    search = params[:search]
    search_value = search[:value] if search.respond_to?(:key?)
    terms = search_value.to_s.split
    terms.reduce(records) do |scope, term|
      scope.where(TERM_CONDITION, term: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%")
    end
  end

  # The gem trusts DataTables' request params: a missing order[i][dir] raises
  # NoMethodError and a negative start/length reaches Postgres. Normalize them.
  def sanitize_params(params)
    params = params.deep_dup
    params[:start] = [params[:start].to_i, 0].max if params.key?(:start)
    if params.key?(:length)
      length = params[:length].to_i
      params[:length] = length.between?(1, MAX_PAGE_LENGTH) ? length : DEFAULT_PAGE_LENGTH
    end
    params[:order] = sanitize_order(params[:order]) if params.key?(:order)
    params[:columns] = sanitize_columns(params[:columns]) if params.key?(:columns)
    params
  end

  def sanitize_columns(columns)
    return {} unless columns.respond_to?(:each_pair)

    columns.each_pair.select do |_index, options|
      options.respond_to?(:key?) && view_columns.key?(options[:data].to_s.to_sym)
    end.to_h
  end

  def sanitize_order(order)
    return {} unless order.respond_to?(:each_pair)

    order.each_pair.with_object({}) do |(index, options), sanitized|
      next unless options.respond_to?(:key?) && options[:column].present?

      dir = options[:dir].to_s.downcase == "desc" ? "desc" : "asc"
      sanitized[index] = { column: options[:column].to_s, dir: }
    end
  end

  def name_link(record)
    "<a href=\"#{school_path(record)}\">#{ERB::Util.html_escape(record.name)}</a>".html_safe
  end

  def website_link(record)
    url = ApplicationHelper.safe_link_url(record.website)
    display = ERB::Util.html_escape(record.website.to_s.truncate(30))
    return display unless url

    "<a href=\"#{ERB::Util.html_escape(url)}\" target=\"_blank\" rel=\"noopener noreferrer\">#{display}</a>".html_safe
  end

  def action_links(record)
    edit = "<a class=\"btn btn-info\" href=\"#{edit_school_path(record)}\">Edit</a>"
    delete = "<a class=\"btn btn-outline-danger\" data-confirm=\"Are you sure?\" rel=\"nofollow\" data-method=\"delete\" href=\"#{school_path(record)}\">❌</a>"
    "<span class=\"btn-group\">#{edit} #{delete}</span>".html_safe
  end
end
