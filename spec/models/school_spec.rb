# frozen_string_literal: true

require "rails_helper"

RSpec.describe School, type: :model do
  fixtures :all

  let(:school) { schools(:berkeley) }

  describe "#website" do
    it "keeps http(s) URLs as-is" do
      school[:website] = "http://example.edu"
      expect(school.website).to eq "http://example.edu"
    end

    it "prefixes scheme-less URLs with https://" do
      school[:website] = "example.edu"
      expect(school.website).to eq "https://example.edu"
    end

    it "does not let a later line's http: prefix pass a javascript: URL" do
      school[:website] = "javascript:alert(1)//\nhttp://x.y"
      expect(school.website).to start_with("https://javascript:")
    end
  end

end
