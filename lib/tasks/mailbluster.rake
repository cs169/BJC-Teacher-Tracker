# frozen_string_literal: true

namespace :mailbluster do
  desc "Sync all validated teachers to MailBluster"
  task sync_all: :environment do
    unless MailblusterService.configured?
      puts "MailBluster API key not configured. Set MAILBLUSTER_API_KEY environment variable."
      exit 1
    end

    results = MailblusterService.sync_all_teachers
    puts "MailBluster sync complete:"
    puts "  Synced: #{results[:synced]}"
    puts "  Failed: #{results[:failed]}"
    puts "  Errors: #{results[:errors].join(', ')}" if results[:errors].any?
  end

  desc "Sync a single teacher to MailBluster by teacher ID"
  task :sync_teacher, [:teacher_id] => :environment do |_t, args|
    unless MailblusterService.configured?
      puts "MailBluster API key not configured. Set MAILBLUSTER_API_KEY environment variable."
      exit 1
    end

    teacher = Teacher.find_by(id: args[:teacher_id])
    if teacher.nil?
      puts "Teacher with ID #{args[:teacher_id]} not found."
      exit 1
    end

    result = MailblusterService.sync_teacher(teacher)
    if result[:success]
      puts "Successfully synced #{teacher.full_name} (#{teacher.primary_email_address&.email})"
    else
      puts "Failed to sync #{teacher.full_name}: #{result[:error]}"
    end
  end

  desc "Show MailBluster sync status for all teachers"
  task status: :environment do
    total = Teacher.count
    synced = Teacher.where.not(mailbluster_synced_at: nil).count
    unsynced = total - synced
    puts "MailBluster sync status:"
    puts "  Total teachers: #{total}"
    puts "  Synced: #{synced}"
    puts "  Not synced: #{unsynced}"
    puts "  API configured: #{MailblusterService.configured? ? 'Yes' : 'No'}"
  end
end
