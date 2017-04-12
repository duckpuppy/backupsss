require 'spec_helper'
require 'backupsss/configuration'

describe Backupsss::Configuration do
  context '#initialize' do
    describe 'attributes' do
      let(:invalid_args) do
        {
          s3_bucket_prefix: 'mah_bucket_key',
          backup_src_dir:   '/local/path',
          backup_dest_dir:  '/backup',
          backup_freq:      '0 * * * *',
          aws_region:       'us-east-1'
        }
      end

      let(:no_schedule_args) do
        {
          s3_bucket:        'mah_bucket',
          s3_bucket_prefix: 'mah_bucket_key',
          backup_src_dir:   '/local/path',
          backup_dest_dir:  '/backup',
          aws_region:       'us-east-1'
        }
      end

      let(:missing_arg) { 's3_bucket' }

      it 'does not raise if backup_freq is not supplied' do
        expect { Backupsss::Configuration.new(no_schedule_args) }
          .to_not raise_error(ArgumentError)
      end

      it 'raises ArgumentError when attributes are missing' do
        expect { Backupsss::Configuration.new(invalid_args) }
          .to raise_error(ArgumentError)
      end

      it 'raises Argument error with missing attribute in message' do
        expected_msg  = "Missing '#{missing_arg}'\n"
        expected_msg += "Args should be passed in or set in the env:\n"
        expected_msg += "#{missing_arg.upcase}=value backupsss"

        expect { Backupsss::Configuration.new(invalid_args) }
          .to raise_error(/#{expected_msg}/)
      end
    end

    it 'can receive custom attributes' do
      config = Backupsss::Configuration.new(
        s3_bucket:        'a_bucket',
        s3_bucket_prefix: 'mah_bucket_key',
        backup_src_dir:   '/local/path',
        backup_dest_dir:  '/backup',
        backup_freq:      '0 * * * *',
        aws_region:       'us-east-1',
        remote_retention: 2
      )

      expect(config.s3_bucket).to        eq('a_bucket')
      expect(config.s3_bucket_prefix).to eq('mah_bucket_key')
      expect(config.backup_src_dir).to   eq('/local/path')
      expect(config.backup_dest_dir).to  eq('/backup')
      expect(config.backup_freq).to      eq('0 * * * *')
      expect(config.aws_region).to       eq('us-east-1')
      expect(config.remote_retention).to eq(2)
    end

    it 'can set attributes with env vars' do
      stub_const(
        'ENV',
        'S3_BUCKET'        => 'mah_bucket',
        'S3_BUCKET_PREFIX' => 'mah_bucket_key',
        'BACKUP_SRC_DIR'   => '/local/path',
        'BACKUP_DEST_DIR'  => '/backup',
        'BACKUP_FREQ'      => '0 * * * *',
        'AWS_REGION'       => 'us-east-1',
        'REMOTE_RETENTION' => '2'
      )
      config = Backupsss::Configuration.new

      expect(config.s3_bucket).to        eq('mah_bucket')
      expect(config.s3_bucket_prefix).to eq('mah_bucket_key')
      expect(config.backup_src_dir).to   eq('/local/path')
      expect(config.backup_dest_dir).to  eq('/backup')
      expect(config.backup_freq).to      eq('0 * * * *')
      expect(config.aws_region).to       eq('us-east-1')
      expect(config.remote_retention).to eq(2)
    end
  end
end
