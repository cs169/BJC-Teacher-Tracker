# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "ses rake tasks" do
  fixtures :all

  before(:all) do
    @original_rake_app = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    Rake.application.rake_require("tasks/ses_simulate", [Rails.root.join("lib").to_s])
  end

  after(:all) do
    Rake.application = @original_rake_app
  end

  describe "ses:simulate" do
    let(:task) { Rake::Task["ses:simulate"] }
    let(:email) { email_addresses(:validated_teacher_email) }

    after { task.reenable }

    it "refuses to run in production and leaves the address untouched" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      expect {
        task.invoke(email.email, "hard_bounce")
      }.to raise_error(SystemExit).and output(/Refusing to run in production/).to_stderr

      expect(email.reload.bounced?).to be false
      expect(SesDeliveryEvent.count).to eq(0)
    end

    it "fires the event in test" do
      expect {
        task.invoke(email.email, "hard_bounce")
      }.to output(/Fired Bounce/).to_stdout
      expect(email.reload.bounced?).to be true
    end
  end
end
