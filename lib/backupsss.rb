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
  class << self
    def config
      @config ||= Backupsss::Configuration.new
    end

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

    def run
      scheduler = Rufus::Scheduler.new
      scheduler.cron(config.backup_freq, blocking: true) do
        begin
          call
        rescue => exc
          $stderr.puts "ERROR - backup failed: #{exc.message}"
          $stderr.puts exc.backtrace.join("\n\t")
        end
      end
      scheduler.join
    end
  end
end
