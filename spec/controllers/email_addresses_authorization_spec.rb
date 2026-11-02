# frozen_string_literal: true

require "rails_helper"

# Login emails are admin-managed. Any address on a teacher can be used to sign
# in as them, and addresses aren't verified, so teachers can't add their own.
RSpec.describe EmailAddressesController, type: :request do
  fixtures :all

  let(:admin) { teachers(:admin) }
  let(:teacher) { teachers(:validated_teacher) }

  it "does not let a teacher add an email to their own account" do
    log_in(teacher)

    expect { post teacher_email_address_path(teacher), params: { email: "squatted@example.com" } }
      .not_to change(EmailAddress, :count)
    expect(response).to redirect_to(root_path)
  end

  it "does not let a teacher delete their own email" do
    extra = teacher.email_addresses.create!(email: "extra-own@example.com", primary: false)
    log_in(teacher)

    expect { delete teacher_delete_email_address_path(teacher, extra) }
      .not_to change(EmailAddress, :count)
  end

  it "checks authorization before looking up the teacher" do
    log_in(teacher)

    post teacher_email_address_path(teacher_id: 999_999_999), params: { email: "probe@example.com" }

    expect(response).to redirect_to(root_path)
  end

  it "lets an admin add an email" do
    log_in(admin)

    expect { post teacher_email_address_path(teacher), params: { email: "added-by-admin@example.com" } }
      .to change { teacher.email_addresses.count }.by(1)
  end

  it "does not let an admin delete a primary email" do
    teacher.email_addresses.create!(email: "backup@example.com", primary: false)
    primary = teacher.email_addresses.find_by(primary: true)
    log_in(admin)

    expect { delete teacher_delete_email_address_path(teacher, primary) }
      .not_to change(EmailAddress, :count)
    expect(flash[:alert]).to eq("Make another email primary before deleting this one.")
  end
end
