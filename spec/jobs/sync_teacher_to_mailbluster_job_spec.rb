# frozen_string_literal: true

require "rails_helper"

RSpec.describe SyncTeacherToMailblusterJob, type: :job do
  fixtures :all
  include ActiveJob::TestHelper

  let(:teacher) { teachers(:validated_teacher) }

  before do
    allow(MailblusterService).to receive(:configured?).and_return(true)
    allow(MailblusterService).to receive(:create_or_update_lead).and_return({ "id" => 99 })
  end

  it "syncs a validated teacher to MailBluster" do
    described_class.perform_now(teacher.id)
    expect(MailblusterService).to have_received(:create_or_update_lead).with(teacher)
  end

  it "does nothing when teacher is not found" do
    described_class.perform_now(-1)
    expect(MailblusterService).not_to have_received(:create_or_update_lead)
  end

  it "does nothing when MailBluster is not configured" do
    allow(MailblusterService).to receive(:configured?).and_return(false)
    described_class.perform_now(teacher.id)
    expect(MailblusterService).not_to have_received(:create_or_update_lead)
  end

  it "does nothing for unvalidated teacher without mailbluster_id" do
    teacher.update_columns(application_status: "Not Reviewed", mailbluster_id: nil)
    described_class.perform_now(teacher.id)
    expect(MailblusterService).not_to have_received(:create_or_update_lead)
  end

  it "still syncs unvalidated teacher that has a mailbluster_id" do
    teacher.update_columns(application_status: "Not Reviewed", mailbluster_id: 42)
    described_class.perform_now(teacher.id)
    expect(MailblusterService).to have_received(:create_or_update_lead).with(teacher)
  end

  it "can be enqueued" do
    expect {
      described_class.perform_later(teacher.id)
    }.to have_enqueued_job(described_class).with(teacher.id).on_queue("default")
  end
end
