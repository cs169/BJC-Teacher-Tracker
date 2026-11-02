# frozen_string_literal: true

module ApplicationHelper
  SAFE_LINK_SCHEMES = %w[http https].freeze

  # Returns an http(s) URL that is safe to use as an href, or nil.
  # Scheme-less values (e.g. "school.edu") are treated as https, matching
  # School#prefix_url. Guards against stored javascript:/data: URLs.
  def self.safe_link_url(url)
    url = url.to_s.strip
    return if url.empty?

    url = "https://#{url}" if URI.parse(url).scheme.nil?
    url if SAFE_LINK_SCHEMES.include?(URI.parse(url).scheme.downcase)
  rescue URI::Error
    nil
  end

  # Links to an external user-supplied URL only when it is http(s);
  # otherwise renders the (escaped) text without a link.
  def safe_external_link(text, url, **options)
    safe_url = ApplicationHelper.safe_link_url(url)
    return text unless safe_url

    options[:rel] = "noopener noreferrer" if options[:target] == "_blank"
    link_to(text, safe_url, **options)
  end

  def alert_class(name)
    case name
    when "alert"
      "danger"
    when "notice"
      "info"
    when "warn"
      "warning"
    else
      name
    end
  end

  def admin_nav_links
    {
      "Dashboard": dashboard_path,
      "Schools": schools_path,
      "Teachers": teachers_path,
      "Email Templates": email_templates_path,
      "PD": professional_developments_path,
    }
  end

  def check_or_x(bool)
    return "✔️" if bool

    "❌"
  end
end
