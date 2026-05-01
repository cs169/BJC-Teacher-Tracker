# frozen_string_literal: true

module TeacherHelper
  SNAP_USER_PAGE = "https://snap.berkeley.edu/user?username="
  def snap_link(teacher)
    return "-" if ["N/A", "None", "", nil].include?(teacher.snap)
    link_to(teacher.snap, "#{SNAP_USER_PAGE}#{teacher.snap}", target: "_blank")
  end

  def ip_history_display(teacher)
    return "-" if teacher.ip_history.nil? || teacher.ip_history.empty?
    teacher.ip_history.to_sentence
  end

  def email_address_label(email)
    labels = []
    labels << '<span class="badge badge-pill badge-primary h6">primary</span>' if email.primary?
    labels << '<span class="badge badge-pill badge-danger h6">bounced</span>' if email.bounced?
    return nil if labels.empty?
    "&nbsp; #{labels.join(' ')}".html_safe
  end

  def mailbluster_sync_status(teacher)
    if teacher.mailbluster_synced?
      url = teacher.mailbluster_profile_url
      if url
        link_to('<span class="badge badge-success">Synced</span>'.html_safe, url, target: "_blank", title: "View in MailBluster")
      else
        '<span class="badge badge-success">Synced</span>'.html_safe
      end
    else
      '<span class="badge badge-secondary">Not Synced</span>'.html_safe
    end
  end
end
