# frozen_string_literal: true

require "rails_helper"

RSpec.describe SnsSubscriptionConfirmer, type: :service do
  let(:valid_url) { "https://sns.us-west-2.amazonaws.com/?Action=ConfirmSubscription&TopicArn=arn:aws:sns:...&Token=xyz" }
  let(:success_response) { instance_double(HTTParty::Response, code: 200, success?: true, body: "<xml/>") }

  describe ".confirm!" do
    it "GETs the SubscribeURL for a valid AWS SNS host" do
      expect(HTTParty).to receive(:get).with(valid_url).and_return(success_response)
      described_class.confirm!(valid_url)
    end

    it "accepts SNS hosts from any region" do
      urls = [
        "https://sns.us-east-1.amazonaws.com/?Token=x",
        "https://sns.eu-west-2.amazonaws.com/?Token=x",
        "https://sns.ap-southeast-1.amazonaws.com/?Token=x"
      ]
      urls.each do |url|
        expect(HTTParty).to receive(:get).with(url).and_return(success_response)
        described_class.confirm!(url)
      end
    end

    it "raises ConfirmationError for a non-AWS host" do
      expect {
        described_class.confirm!("https://evil.example.com/?Token=x")
      }.to raise_error(SnsSubscriptionConfirmer::ConfirmationError, /host/i)
    end

    it "raises ConfirmationError for a non-HTTPS scheme" do
      expect {
        described_class.confirm!("http://sns.us-west-2.amazonaws.com/?Token=x")
      }.to raise_error(SnsSubscriptionConfirmer::ConfirmationError, /https/i)
    end

    it "raises ConfirmationError when the URL is malformed" do
      expect {
        described_class.confirm!("not a url")
      }.to raise_error(SnsSubscriptionConfirmer::ConfirmationError)
    end

    it "raises ConfirmationError when AWS returns a non-2xx response" do
      failure_response = instance_double(HTTParty::Response, code: 403, success?: false, body: "Forbidden")
      allow(HTTParty).to receive(:get).and_return(failure_response)

      expect {
        described_class.confirm!(valid_url)
      }.to raise_error(SnsSubscriptionConfirmer::ConfirmationError, /403/)
    end
  end
end
