require 'aws-sdk'
require 'rufus-scheduler'
require 'backupsss/tar'
require 'backupsss/backup'
require 'backupsss/backup_dir'
require 'backupsss/backup_bucket'
require 'backupsss/janitor'
require 'backupsss/version'
require 'backupsss/configuration'

# A utility for backing things up to S3.
module Backupsss
  # A Class for running this backup utility
  class Runner
    attr_accessor :config

    def initialize
      @config = Backupsss::Configuration.new
    end

    def run
      config.backup_freq ? run_scheduled : run_oneshot
    end

    private

    def call
      push_backup(*prep_for_backup)
      cleanup_local
      cleanup_remote
    end

    def prep_for_backup
      filename = "#{Time.now.to_i}.tar"
      backup   = Backupsss::Backup.new(
        {
          s3_bucket_prefix: config.s3_bucket_prefix,
          s3_bucket:        config.s3_bucket,
          filename:         filename
        }, Aws::S3::Client.new(region: config.aws_region)
      )

      [filename, backup]
    end

    def push_backup(filename, backup)
      puts 'Create and Upload Tar: Starting'
      backup.put_file(
        Backupsss::Tar.new(
          config.backup_src_dir,
          "#{config.backup_dest_dir}/#{filename}"
        ).make
      )
      puts 'Create and Upload Tar: Finished'
    end

    def cleanup_local
      local_janitor = Janitor.new(
        driver: BackupDir.new(dir: config.backup_dest_dir)
      )
      local_janitor.rm_garbage(local_janitor.sift_trash)
    end

    def cleanup_remote
      remote_janitor = Janitor.new(
        driver: BackupBucket.new(
          dir: "#{config.s3_bucket}/#{config.s3_bucket_prefix}",
          region: config.aws_region
        ),
        retention_count: config.remote_retention
      )
      remote_janitor.rm_garbage(remote_janitor.sift_trash)
    end

    def run_scheduled
      $stdout.puts "Schedule provided, running with #{config.backup_freq}"

      scheduler = Rufus::Scheduler.new
      scheduler.cron(config.backup_freq, blocking: true) { make_call }
      scheduler.join
    end

    def run_oneshot
      $stdout.puts 'No Schedule provided, running one time task'

      make_call
    end

    def make_call
      call
    rescue => exc
      abort("ERROR - backup failed: #{exc.message}\n#{exc.backtrace.join("\n\t")}")
    end
  end
end
