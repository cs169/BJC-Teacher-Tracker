# frozen_string_literal: true

require "uri"

class SnsSubscriptionConfirmer
  class ConfirmationError < StandardError; end

  ALLOWED_HOST_REGEX = /\Asns\.[a-z0-9-]+\.amazonaws\.com\z/

  def self.confirm!(subscribe_url)
    new(subscribe_url).confirm!
  end

  def initialize(subscribe_url)
    @subscribe_url = subscribe_url
  end

  def confirm!
    assert_url_safe!

    response = HTTParty.get(@subscribe_url)
    unless response.success?
      raise ConfirmationError, "AWS SNS returned #{response.code} when confirming subscription"
    end
    response
  end

  private
  def assert_url_safe!
    uri =
      begin
        URI.parse(@subscribe_url)
      rescue URI::InvalidURIError => e
        raise ConfirmationError, "Invalid SubscribeURL: #{e.message}"
      end

    raise ConfirmationError, "SubscribeURL must be a URL" if uri.host.nil?
    raise ConfirmationError, "SubscribeURL must use https scheme" unless uri.scheme == "https"
    raise ConfirmationError, "SubscribeURL host #{uri.host.inspect} is not an AWS SNS host" unless uri.host.match?(ALLOWED_HOST_REGEX)
  end
end
