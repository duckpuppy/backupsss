module Backupsss
  # A class for managing the properties need for creating, uploading, and
  # cleaning up backups in S3.
  class Configuration
    def self.defaults
      {
        s3_bucket:        ENV['S3_BUCKET'],
        s3_bucket_prefix: ENV['S3_BUCKET_PREFIX'],
        backup_src_dir:   ENV['BACKUP_SRC_DIR'],
        backup_dest_dir:  ENV['BACKUP_DEST_DIR'],
        backup_freq:      ENV['BACKUP_FREQ'],
        aws_region:       ENV['AWS_REGION'],
        remote_retention: ENV['REMOTE_RETENTION'].to_i
      }
    end

    attr_accessor(*defaults.keys)

    def initialize(opts = {})
      attrs.each do |k, _|
        attr_val = validate_attrs(attrs.merge(opts), k)
        instance_variable_set("@#{k}", attr_val)
      end
    end

    private

    def validate_attrs(attrs, attr_key)
      throwout_nils(attrs).fetch(attr_key) do
        raise ArgumentError, missing_attr_error_msg(attr_key)
      end
    end

    def missing_attr_error_msg(key)
      [
        "Missing '#{key}'",
        'Args should be passed in or set in the env:',
        "#{key.upcase}=value backupsss"
      ].join("\n")
    end

    def throwout_nils(attrs)
      attrs.reject { |k, v| v.nil? && k != :backup_freq  }
    end

    def attrs
      self.class.defaults
    end
  end
end
