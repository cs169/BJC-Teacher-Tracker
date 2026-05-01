# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeacherHelper, type: :helper do
  fixtures :all

  let(:teacher) { teachers(:bob) }

  it "helpers snap_link displays correctly" do
    expect(snap_link(teacher)).to eq "<a target=\"_blank\" href=\"https://snap.berkeley.edu/user?username=BobJohnson\">BobJohnson</a>"
  end

  it "helpers ip_history_display displays correctly" do
    expect(ip_history_display(teacher)).to eq "-"
  end

  describe "#mailbluster_sync_status" do
    it "shows Not Synced badge when teacher has not been synced" do
      result = mailbluster_sync_status(teacher)
      expect(result).to include("Not Synced")
      expect(result).to include("badge-secondary")
    end

    it "shows Synced badge when teacher has been synced" do
      teacher.update_columns(mailbluster_synced_at: Time.current, mailbluster_id: 123)
      result = mailbluster_sync_status(teacher)
      expect(result).to include("Synced")
      expect(result).to include("badge-success")
    end

    it "links Synced badge to MailBluster profile when ID present" do
      teacher.update_columns(mailbluster_synced_at: Time.current, mailbluster_id: 456)
      result = mailbluster_sync_status(teacher)
      expect(result).to include("mailbluster.com")
      expect(result).to include("target=\"_blank\"")
    end
  end

  describe "#email_address_label" do
    it "shows primary badge for primary email" do
      email = teacher.email_addresses.find_by(primary: true)
      result = email_address_label(email)
      expect(result).to include("primary")
    end

    it "shows bounced badge for bounced email" do
      email = teacher.email_addresses.first
      email.update_columns(bounced: true)
      result = email_address_label(email)
      expect(result).to include("bounced")
    end
  end
end
