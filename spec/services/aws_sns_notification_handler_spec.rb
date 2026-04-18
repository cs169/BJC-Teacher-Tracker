# frozen_string_literal: true

require "rails_helper"

RSpec.describe AwsSnsNotificationHandler, type: :service do
  describe "#call" do
    it "confirms SNS subscriptions" do
      envelope = {
        "Type" => "SubscriptionConfirmation",
        "SubscribeURL" => "https://sns.us-west-2.amazonaws.com/confirm"
      }
      response = instance_double(HTTParty::Response, success?: true)

      expect(HTTParty).to receive(:get).with(envelope["SubscribeURL"]).and_return(response)

      described_class.new(envelope).call
    end

    it "hands notifications to the SES processor" do
      envelope = {
        "Type" => "Notification",
        "MessageId" => "sns-1",
        "TopicArn" => "arn:aws:sns:test",
        "Message" => { eventType: "Delivery", mail: { messageId: "ses-1", destination: ["validated@teacher.edu"], tags: { app: ["bjc_teacher_tracker"] } }, delivery: { recipients: ["validated@teacher.edu"], timestamp: "2026-04-18T12:00:00.000Z" } }.to_json
      }
      processor = instance_double(AwsSesEventProcessor, call: 1)

      expect(AwsSesEventProcessor).to receive(:new).with(
        sns_message_id: "sns-1",
        topic_arn: "arn:aws:sns:test",
        ses_event: kind_of(Hash)
      ).and_return(processor)

      described_class.new(envelope).call
    end
  end
end