# frozen_string_literal: true

# == Schema Information
#
# Table name: email_templates
#
#  id         :bigint           not null, primary key
#  body       :text
#  format     :string
#  handler    :string
#  locale     :string
#  partial    :boolean
#  path       :string
#  required   :boolean          default(FALSE)
#  subject    :string
#  title      :string
#  to         :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "rails_helper"

RSpec.describe EmailTemplate, type: :model do
  describe "#accepts_custom_reason?" do
    it "returns true if a reason is present in the body" do
      template = EmailTemplate.new(body: " ... {{ denial_reason }}...")
      expect(template.accepts_custom_reason?).to be true
    end

    it "returns true even if there are other liquid filters" do
      template = EmailTemplate.new(body: " ... {{denial_reason|strip_tags}}...")
      expect(template.accepts_custom_reason?).to be true
    end

    it "returns false if no reason is in the body" do
      template = EmailTemplate.new(body: "")
      expect(template.accepts_custom_reason?).to be false
    end
  end
end
