# frozen_string_literal: true

require "digest/md5"

class MailblusterService
  BASE_URL = "https://api.mailbluster.com/api"

  class MailblusterError < StandardError; end

  class << self
    # Create or update a lead in MailBluster for a given teacher.
    # Uses overrideExisting to upsert.
    # Returns the MailBluster lead hash on success, nil on failure.
    def create_or_update_lead(teacher)
      email = teacher.primary_email
      return nil if email.blank?

      body = lead_payload(teacher)
      body[:overrideExisting] = true

      response = post("/leads", body)

      if response.success?
        lead_data = response.parsed_response["lead"]
        if lead_data && lead_data["id"]
          teacher.update_columns(
            mailbluster_id: lead_data["id"],
            mailbluster_synced_at: Time.current
          )
        end
        lead_data
      else
        Rails.logger.error("[MailBluster] Failed to create/update lead for teacher #{teacher.id}: #{response.body}")
        nil
      end
    end

    # Read a lead from MailBluster by email address.
    # Returns the lead hash or nil.
    def read_lead(email)
      lead_hash = md5_hash(email)
      response = get("/leads/#{lead_hash}")

      if response.success?
        response.parsed_response
      else
        Rails.logger.warn("[MailBluster] Lead not found for #{email}: #{response.code}")
        nil
      end
    end

    # Delete a lead from MailBluster by email address.
    def delete_lead(email)
      lead_hash = md5_hash(email)
      response = delete("/leads/#{lead_hash}")
      response.success?
    end

    # Sync all validated (non-admin) teachers to MailBluster.
    # Returns a summary hash with counts.
    # Includes a small delay between requests to avoid rate limiting.
    def sync_all_teachers
      teachers = Teacher.where(admin: false)
                        .where(application_status: "Validated")
                        .includes(:email_addresses, :school)

      results = { synced: 0, failed: 0, skipped: 0, errors: [] }

      teachers.find_each do |teacher|
        if teacher.primary_email.blank?
          results[:skipped] += 1
          next
        end

        lead_data = create_or_update_lead(teacher)
        if lead_data
          results[:synced] += 1
        else
          results[:failed] += 1
          results[:errors] << "Teacher #{teacher.id} (#{teacher.full_name})"
        end

        # Small delay between API calls to respect rate limits
        sleep(0.1) if results[:synced] + results[:failed] > 0
      rescue StandardError => e
        results[:failed] += 1
        results[:errors] << "Teacher #{teacher.id}: #{e.message}"
      end

      results
    end

    # Sync a single teacher to MailBluster.
    # Returns a hash with :success and optionally :error.
    def sync_teacher(teacher)
      lead_data = create_or_update_lead(teacher)
      if lead_data.present?
        { success: true }
      else
        { success: false, error: "MailBluster API returned no lead data" }
      end
    rescue StandardError => e
      Rails.logger.error("[MailBluster] Error syncing teacher #{teacher.id}: #{e.message}")
      { success: false, error: e.message }
    end

    # Check if the API key is configured.
    def configured?
      api_key.present?
    end

    private
    def api_key
      ENV["MAILBLUSTER_API_KEY"]
    end

    def md5_hash(email)
      Digest::MD5.hexdigest(email.strip.downcase)
    end

    def lead_payload(teacher)
      payload = {
        email: teacher.primary_email,
        firstName: teacher.first_name,
        lastName: teacher.last_name,
        subscribed: teacher.validated?,
        tags: lead_tags(teacher),
      }

      # Add timezone from school if available
      timezone = school_timezone(teacher)
      payload[:timezone] = timezone if timezone.present?

      # Add IP address if available
      if teacher.ip_history.present?
        payload[:ipAddress] = teacher.ip_history.last.to_s
      end

      # Add custom fields
      payload[:fields] = {
        school_name: teacher.school&.name,
        school_city: teacher.school&.city,
        school_state: teacher.school&.state,
        application_status: teacher.application_status,
        snap_username: teacher.snap,
        education_level: teacher.education_level,
      }.compact

      payload
    end

    def lead_tags(teacher)
      tags = ["BJC Teacher"]
      tags << teacher.application_status.titlecase if teacher.application_status.present?
      tags << teacher.status.to_s.titlecase if teacher.status.present?
      tags
    end

    def school_timezone(teacher)
      return nil unless teacher.school

      # Use the school's state to approximate timezone.
      # This is a simplified mapping; a full implementation would use
      # geocoding or a timezone database.
      state = teacher.school.state
      return nil if state.blank?

      US_STATE_TIMEZONES[state.upcase] || US_STATE_TIMEZONES[state.titlecase]
    end

    def headers
      {
        "Authorization" => api_key,
        "Content-Type" => "application/json",
      }
    end

    def post(path, body)
      HTTParty.post(
        "#{BASE_URL}#{path}",
        headers:,
        body: body.to_json
      )
    end

    def get(path)
      HTTParty.get(
        "#{BASE_URL}#{path}",
        headers:
      )
    end

    def delete(path)
      HTTParty.delete(
        "#{BASE_URL}#{path}",
        headers:
      )
    end

    # Simplified US state → timezone mapping.
    # MailBluster accepts IANA timezone strings.
    US_STATE_TIMEZONES = {
      "AL" => "America/Chicago", "AK" => "America/Anchorage", "AZ" => "America/Phoenix",
      "AR" => "America/Chicago", "CA" => "America/Los_Angeles", "CO" => "America/Denver",
      "CT" => "America/New_York", "DE" => "America/New_York", "FL" => "America/New_York",
      "GA" => "America/New_York", "HI" => "Pacific/Honolulu", "ID" => "America/Boise",
      "IL" => "America/Chicago", "IN" => "America/Indiana/Indianapolis",
      "IA" => "America/Chicago", "KS" => "America/Chicago", "KY" => "America/New_York",
      "LA" => "America/Chicago", "ME" => "America/New_York", "MD" => "America/New_York",
      "MA" => "America/New_York", "MI" => "America/Detroit", "MN" => "America/Chicago",
      "MS" => "America/Chicago", "MO" => "America/Chicago", "MT" => "America/Denver",
      "NE" => "America/Chicago", "NV" => "America/Los_Angeles", "NH" => "America/New_York",
      "NJ" => "America/New_York", "NM" => "America/Denver", "NY" => "America/New_York",
      "NC" => "America/New_York", "ND" => "America/Chicago", "OH" => "America/New_York",
      "OK" => "America/Chicago", "OR" => "America/Los_Angeles", "PA" => "America/New_York",
      "RI" => "America/New_York", "SC" => "America/New_York", "SD" => "America/Chicago",
      "TN" => "America/Chicago", "TX" => "America/Chicago", "UT" => "America/Denver",
      "VT" => "America/New_York", "VA" => "America/New_York", "WA" => "America/Los_Angeles",
      "WV" => "America/New_York", "WI" => "America/Chicago", "WY" => "America/Denver",
      "DC" => "America/New_York",
    }.freeze
  end
end
