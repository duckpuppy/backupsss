require 'spec_helper'
require 'rufus-scheduler'
require 'backupsss'

describe Backupsss do
  it 'has a version number' do
    expect(Backupsss::VERSION).not_to be nil
  end

  describe Backupsss::Runner do
    describe '#new' do
      before do
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
      end

      subject { Backupsss::Runner.new.config }

      it { is_expected.to be_kind_of(Backupsss::Configuration) }
    end

    describe '#run' do
      let(:scheduler) { instance_double(Rufus::Scheduler) }

      before do
        allow(Rufus::Scheduler).to receive(:new).and_return(scheduler)
        allow(scheduler).to receive(:cron)
        allow(scheduler).to receive(:join)
      end

      describe 'has schedule' do
        before do
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
        end

        it 'should notify running scheduled job' do
          msg = "Schedule provided, running with #{ENV['BACKUP_FREQ']}\n"

          expect { subject.run }.to output(msg).to_stdout
        end

        it "should call scheduler's cron and join methods" do
          expect(scheduler).to receive(:cron).with(
            ENV['BACKUP_FREQ'], blocking: true
          )
          expect(scheduler).to receive(:join)

          subject.run
        end
      end

      describe 'has no schedule' do
        before do
          stub_const(
            'ENV',
            'S3_BUCKET'        => 'mah_bucket',
            'S3_BUCKET_PREFIX' => 'mah_bucket_key',
            'BACKUP_SRC_DIR'   => '/local/path',
            'BACKUP_DEST_DIR'  => '/backup',
            'AWS_REGION'       => 'us-east-1',
            'REMOTE_RETENTION' => '2'
          )

          allow(subject).to receive(:call)
        end

        it 'should notify running one time job' do
          msg = "No Schedule provided, running one time task\n"

          expect { subject.run }.to output(msg).to_stdout
        end

        it 'rescues from exceptions and writes a message to STDERR' do
          err_msg = 'ERROR - backup failed: myerror'
          allow(subject).to receive(:call).and_raise(RuntimeError, 'myerror')

          expect { subject.run }.to output(/#{err_msg}/).to_stderr
        end
      end
    end
  end
end
