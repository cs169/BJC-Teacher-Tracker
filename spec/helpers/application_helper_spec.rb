# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe ".safe_link_url" do
    it "allows http and https URLs" do
      expect(described_class.safe_link_url("https://example.edu")).to eq "https://example.edu"
      expect(described_class.safe_link_url("HTTP://example.edu")).to eq "HTTP://example.edu"
    end

    it "treats scheme-less URLs as https" do
      expect(described_class.safe_link_url("example.edu/~me")).to eq "https://example.edu/~me"
    end

    it "rejects other schemes and unparseable URLs" do
      expect(described_class.safe_link_url("javascript:alert(1)")).to be_nil
      expect(described_class.safe_link_url(" JavaScript:alert(1)")).to be_nil
      expect(described_class.safe_link_url("data:text/html,<script>alert(1)</script>")).to be_nil
      expect(described_class.safe_link_url("https://javascript:alert(1)//\nhttp://x.y")).to be_nil
      expect(described_class.safe_link_url(nil)).to be_nil
    end
  end

  describe "#safe_external_link" do
    it "links safe URLs, adding rel=noopener for new tabs" do
      html = helper.safe_external_link("(Web)", "https://example.edu", target: "_blank")
      expect(html).to include('href="https://example.edu"')
      expect(html).to include('rel="noopener noreferrer"')
    end

    it "renders unsafe URLs as escaped text without a link" do
      html = helper.safe_external_link("<b>x</b>", "javascript:alert(1)")
      expect(html).not_to include("href")
      expect(ERB::Util.html_escape(html)).to eq "&lt;b&gt;x&lt;/b&gt;"
    end
  end
end
