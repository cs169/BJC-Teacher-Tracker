# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailblusterService, type: :service do
  fixtures :all

  let(:teacher) { teachers(:validated_teacher) }
  let(:api_key) { "test-api-key-12345" }

  let(:success_response) do
    instance_double(HTTParty::Response,
      success?: true,
      parsed_response: {
        "message" => "Lead added",
        "lead" => {
          "id" => 329395,
          "firstName" => teacher.first_name,
          "lastName" => teacher.last_name,
          "email" => teacher.primary_email,
          "subscribed" => true,
          "tags" => ["BJC Teacher"],
          "createdAt" => "2026-04-10T00:00:00.000Z",
          "updatedAt" => "2026-04-10T00:00:00.000Z"
        }
      },
      body: '{"message":"Lead added"}')
  end

  let(:failure_response) do
    instance_double(HTTParty::Response,
      success?: false,
      parsed_response: { "message" => "Something went wrong" },
      body: '{"message":"Something went wrong"}',
      code: 500)
  end

  let(:read_success_response) do
    instance_double(HTTParty::Response,
      success?: true,
      parsed_response: {
        "id" => 329395,
        "firstName" => "Validated",
        "lastName" => "Teacher",
        "email" => "validated@teacher.edu",
        "subscribed" => true
      },
      code: 200)
  end

  let(:not_found_response) do
    instance_double(HTTParty::Response,
      success?: false,
      parsed_response: { "message" => "Lead not found" },
      code: 404)
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MAILBLUSTER_API_KEY").and_return(api_key)
  end

  describe ".configured?" do
    it "returns true when API key is set" do
      expect(described_class.configured?).to be true
    end

    it "returns false when API key is blank" do
      allow(ENV).to receive(:[]).with("MAILBLUSTER_API_KEY").and_return(nil)
      expect(described_class.configured?).to be false
    end
  end

  describe ".create_or_update_lead" do
    it "sends a POST request to create a lead" do
      expect(HTTParty).to receive(:post)
        .with(
          "https://api.mailbluster.com/api/leads",
          hash_including(
            headers: hash_including("Authorization" => api_key),
            body: anything
          )
        )
        .and_return(success_response)

      result = described_class.create_or_update_lead(teacher)
      expect(result).to be_present
      expect(result["id"]).to eq(329395)
    end

    it "stores mailbluster_id on the teacher after successful sync" do
      allow(HTTParty).to receive(:post).and_return(success_response)

      described_class.create_or_update_lead(teacher)
      teacher.reload

      expect(teacher.mailbluster_id).to eq(329395)
      expect(teacher.mailbluster_synced_at).to be_present
    end

    it "returns nil when the API call fails" do
      allow(HTTParty).to receive(:post).and_return(failure_response)

      result = described_class.create_or_update_lead(teacher)
      expect(result).to be_nil
    end

    it "returns nil when teacher has no primary email" do
      allow(teacher).to receive(:primary_email).and_return(nil)

      result = described_class.create_or_update_lead(teacher)
      expect(result).to be_nil
    end

    it "includes overrideExisting in the request body" do
      expect(HTTParty).to receive(:post) do |_url, options|
        body = JSON.parse(options[:body])
        expect(body["overrideExisting"]).to be true
        success_response
      end

      described_class.create_or_update_lead(teacher)
    end

    it "includes teacher name and email in the payload" do
      expect(HTTParty).to receive(:post) do |_url, options|
        body = JSON.parse(options[:body])
        expect(body["firstName"]).to eq(teacher.first_name)
        expect(body["lastName"]).to eq(teacher.last_name)
        expect(body["email"]).to eq(teacher.primary_email)
        success_response
      end

      described_class.create_or_update_lead(teacher)
    end

    it "sets subscribed to true for validated teachers" do
      expect(HTTParty).to receive(:post) do |_url, options|
        body = JSON.parse(options[:body])
        expect(body["subscribed"]).to be true
        success_response
      end

      described_class.create_or_update_lead(teacher)
    end

    it "includes BJC Teacher tag" do
      expect(HTTParty).to receive(:post) do |_url, options|
        body = JSON.parse(options[:body])
        expect(body["tags"]).to include("BJC Teacher")
        success_response
      end

      described_class.create_or_update_lead(teacher)
    end
  end

  describe ".read_lead" do
    it "fetches a lead by email using MD5 hash" do
      email = "validated@teacher.edu"
      md5_hash = Digest::MD5.hexdigest(email)

      expect(HTTParty).to receive(:get)
        .with(
          "https://api.mailbluster.com/api/leads/#{md5_hash}",
          hash_including(headers: hash_including("Authorization" => api_key))
        )
        .and_return(read_success_response)

      result = described_class.read_lead(email)
      expect(result["id"]).to eq(329395)
    end

    it "returns nil when lead is not found" do
      allow(HTTParty).to receive(:get).and_return(not_found_response)

      result = described_class.read_lead("unknown@email.com")
      expect(result).to be_nil
    end
  end

  describe ".delete_lead" do
    it "sends a DELETE request using MD5 hash of email" do
      email = "validated@teacher.edu"
      md5_hash = Digest::MD5.hexdigest(email)
      delete_response = instance_double(HTTParty::Response, success?: true)

      expect(HTTParty).to receive(:delete)
        .with(
          "https://api.mailbluster.com/api/leads/#{md5_hash}",
          hash_including(headers: hash_including("Authorization" => api_key))
        )
        .and_return(delete_response)

      expect(described_class.delete_lead(email)).to be true
    end
  end

  describe ".sync_teacher" do
    it "returns success hash on successful sync" do
      allow(HTTParty).to receive(:post).and_return(success_response)

      result = described_class.sync_teacher(teacher)
      expect(result[:success]).to be true
    end

    it "returns failure hash on failed sync" do
      allow(HTTParty).to receive(:post).and_return(failure_response)

      result = described_class.sync_teacher(teacher)
      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end

    it "handles unexpected errors gracefully" do
      allow(HTTParty).to receive(:post).and_raise(StandardError, "connection timeout")

      result = described_class.sync_teacher(teacher)
      expect(result[:success]).to be false
      expect(result[:error]).to include("connection timeout")
    end
  end

  describe ".sync_all_teachers" do
    it "syncs all validated non-admin teachers" do
      allow(HTTParty).to receive(:post).and_return(success_response)

      results = described_class.sync_all_teachers
      expect(results[:synced]).to be >= 1
      expect(results[:failed]).to eq(0)
    end

    it "skips teachers without primary emails" do
      # Remove primary email from validated teacher
      teacher.email_addresses.where(primary: true).destroy_all

      allow(HTTParty).to receive(:post).and_return(success_response)

      results = described_class.sync_all_teachers
      expect(results[:skipped]).to be >= 1
    end

    it "tracks failed syncs" do
      allow(HTTParty).to receive(:post).and_return(failure_response)

      results = described_class.sync_all_teachers
      expect(results[:failed]).to be >= 1
      expect(results[:errors]).not_to be_empty
    end

    it "handles exceptions gracefully" do
      allow(HTTParty).to receive(:post).and_raise(StandardError.new("Connection timeout"))

      results = described_class.sync_all_teachers
      expect(results[:failed]).to be >= 1
      expect(results[:errors].first).to include("Connection timeout")
    end
  end
end
