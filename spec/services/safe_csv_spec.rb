# frozen_string_literal: true

require "rails_helper"

RSpec.describe SafeCsv do
  describe ".escape" do
    ["=1+1", "+1", "-1", "@SUM(A1)", "\tx", "\rx", "=HYPERLINK(\"https://evil.example\")"].each do |value|
      it "quotes #{value.inspect}" do
        expect(described_class.escape(value)).to eq("'#{value}")
      end
    end

    it "leaves ordinary strings alone" do
      expect(described_class.escape("Berkeley High")).to eq("Berkeley High")
      expect(described_class.escape("a=b")).to eq("a=b")
    end

    it "leaves non-strings alone" do
      expect(described_class.escape(-5)).to eq(-5)
      expect(described_class.escape(nil)).to be_nil
    end
  end
end
